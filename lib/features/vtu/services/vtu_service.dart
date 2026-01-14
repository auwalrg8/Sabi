import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sabi_wallet/config/vtu_config.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/contact_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/ln_address_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/services/payment_retry_service.dart';
import 'package:uuid/uuid.dart';

import '../data/models/models.dart';
import 'vtu_api_service.dart';

/// Service for managing VTU (Virtual Top-Up) operations
/// Now with automatic payment and VTU.ng API integration
class VtuService {
  static const String _ordersBoxName = 'vtu_orders';
  static const _uuid = Uuid();

  /// Open or get the VTU orders Hive box
  static Future<Box> _openOrdersBox() async {
    if (Hive.isBoxOpen(_ordersBoxName)) {
      return Hive.box(_ordersBoxName);
    }
    return await Hive.openBox(_ordersBoxName);
  }

  /// Convert Naira amount to Satoshis (with markup)
  static Future<int> nairaToSats(double naira) async {
    // Apply markup for agent profit
    final nairaWithMarkup = naira * (1 + VtuConfig.markupPercentage);
    final btcNgnRate = await RateService.getBtcToNgnRate();
    // naira / rate = BTC, then * 100,000,000 = sats
    final btc = nairaWithMarkup / btcNgnRate;
    final sats = (btc * 100000000).round();
    return sats;
  }

  /// Convert Satoshis to Naira
  static Future<double> satsToNaira(int sats) async {
    return await RateService.satsToNgn(sats);
  }

  /// Get airtime amounts (can be customized)
  static List<double> getAirtimeAmounts() {
    return [50, 100, 200, 500, 1000, 2000, 5000, 10000];
  }

  /// Get electricity amounts
  static List<double> getElectricityAmounts() {
    return [1000, 2000, 3000, 5000, 10000, 20000, 50000];
  }

  /// Check if user has sufficient balance
  static Future<bool> hasSufficientBalance(int amountSats) async {
    try {
      final balance = await BreezSparkService.getBalance();
      return balance >= amountSats;
    } catch (e) {
      debugPrint('❌ Balance check error: $e');
      return false;
    }
  }

  /// Get current user balance in sats
  static Future<int> getUserBalance() async {
    try {
      return await BreezSparkService.getBalance();
    } catch (e) {
      debugPrint('❌ Get balance error: $e');
      return 0;
    }
  }

  /// Validate transaction requirements (User balance & Agent liquidity)
  static Future<void> validateTransaction(double amountNaira) async {
    final amountSats = await nairaToSats(amountNaira);
    
    // 1. Check User Balance
    if (!await hasSufficientBalance(amountSats)) {
      throw InsufficientBalanceException(
        required: amountSats,
        available: await getUserBalance(),
      );
    }

    // 2. Check Agent Liquidity (Optional but recommended)
    // We check if the VTU wallet has enough funds to fulfill the order
    if (!await hasVtuLiquidity(amountNaira)) {
      throw const VtuServiceException(
        'Service temporarily unavailable (Low Liquidity). Please try again later.',
      );
    }
  }

  /// Process VTU purchase - Deliver First, Then Pay (Escrow-like)
  /// Returns the completed order or throws on failure
  static Future<VtuOrder> processAirtimePurchase({
    required String phone,
    required String networkCode,
    required double amountNaira,
  }) async {
    final amountSats = await nairaToSats(amountNaira);

    // Step 1: Deep Validation
    await validateTransaction(amountNaira);

    // Step 2: Create pending order
    final order = await _createOrder(
      serviceType: VtuServiceType.airtime,
      recipient: phone,
      amountNaira: amountNaira,
      amountSats: amountSats,
      networkCode: networkCode,
    );

    try {
      // Step 3: Mark as processing
      await updateOrderStatus(order.id, VtuOrderStatus.processing);

      // Step 4: Call VTU.ng API to deliver airtime (OPTIMISTIC DELIVERY)
      debugPrint('🚀 Delivery First: Attempting API call for ${order.id}');
      final apiResponse = await VtuApiService.buyAirtime(
        phone: formatPhoneNumber(phone),
        networkCode: networkCode,
        amount: amountNaira.toInt(),
      );

      if (apiResponse.success) {
        debugPrint('✅ Delivery Successful. Charging user...');

        // Step 5: Charge User (Payment Settlement)
        try {
          await _payToAgent(
            amountSats,
            'Airtime: ₦${amountNaira.toInt()} to $phone',
          );

          // Step 6: Mark as completed
          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
          );

          // Save to recent contacts
          await _saveToRecentContacts(phone, 'Airtime Purchase');

          return completedOrder!;

        } catch (paymentError) {
          debugPrint('⚠️ Payment to agent failed after delivery: $paymentError');

          // Enqueue background retry to settle the agent
          await PaymentRetryService.enqueue(
            orderId: order.id,
            sats: amountSats,
            memo: 'Airtime: ₦${amountNaira.toInt()} to $phone',
            lnAddress: VtuConfig.lightningAddress,
          );

          // Mark order as completed for the user, but note settlement pending
          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
            errorMessage: 'Delivery successful — settlement pending (will retry in background).',
          );

          // Save to recent contacts
          await _saveToRecentContacts(phone, 'Airtime Purchase');

          return completedOrder!;
        }
      } else {
        // VTU.ng failed - No charge to user
        await updateOrderStatus(
          order.id,
          VtuOrderStatus.failed,
          errorMessage: apiResponse.message,
        );
        throw VtuDeliveryException(
          apiResponse.message,
          errorType: apiResponse.errorType,
          isRecoverable: apiResponse.isRecoverable,
        );
      }
    } catch (e) {
      if (e is InsufficientBalanceException ||
          e is VtuDeliveryException ||
          e is PaymentFailedException) {
        rethrow;
      }
      
      // Other errors - mark order as failed
      await updateOrderStatus(
        order.id,
        VtuOrderStatus.failed,
        errorMessage: e.toString(),
      );
      throw VtuServiceException(e.toString());
    }
  }

  /// Process data bundle purchase
  static Future<VtuOrder> processDataPurchase({
    required String phone,
    required String networkCode,
    required String variationId,
    required double amountNaira,
    required String planName,
  }) async {
    final amountSats = await nairaToSats(amountNaira);

    // Step 1: Deep Validation
    await validateTransaction(amountNaira);

    final order = await _createOrder(
      serviceType: VtuServiceType.data,
      recipient: phone,
      amountNaira: amountNaira,
      amountSats: amountSats,
      networkCode: networkCode,
      dataPlanId: variationId,
    );

    try {
      await updateOrderStatus(order.id, VtuOrderStatus.processing);
      
      debugPrint('🚀 Delivery First: Attempting Data API call for ${order.id}');
      final apiResponse = await VtuApiService.buyData(
        phone: formatPhoneNumber(phone),
        networkCode: networkCode,
        variationId: variationId,
      );

      if (apiResponse.success) {
        debugPrint('✅ Delivery Successful. Charging user...');

        try {
          await _payToAgent(amountSats, 'Data: $planName to $phone');

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
          );

          await _saveToRecentContacts(phone, 'Data Purchase');
          return completedOrder!;

        } catch (paymentError) {
          debugPrint('⚠️ Payment to agent failed after delivery: $paymentError');

          await PaymentRetryService.enqueue(
            orderId: order.id,
            sats: amountSats,
            memo: 'Data: $planName to $phone',
            lnAddress: VtuConfig.lightningAddress,
          );

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
            errorMessage: 'Delivery successful — settlement pending (will retry in background).',
          );

          await _saveToRecentContacts(phone, 'Data Purchase');
          return completedOrder!;
        }
      } else {
        await updateOrderStatus(
          order.id,
          VtuOrderStatus.failed,
          errorMessage: apiResponse.message,
        );
        throw VtuDeliveryException(
          apiResponse.message,
          errorType: apiResponse.errorType,
          isRecoverable: apiResponse.isRecoverable,
        );
      }
    } catch (e) {
      if (e is InsufficientBalanceException ||
          e is VtuDeliveryException ||
          e is PaymentFailedException) {
        rethrow;
      }
      await updateOrderStatus(
        order.id,
        VtuOrderStatus.failed,
        errorMessage: e.toString(),
      );
      throw VtuServiceException(e.toString());
    }
  }

  /// Process electricity purchase
  static Future<VtuOrder> processElectricityPurchase({
    required String meterNumber,
    required String discoCode,
    required String meterType,
    required double amountNaira,
    required String phone,
  }) async {
    final amountSats = await nairaToSats(amountNaira);

    // Step 1: Deep Validation
    await validateTransaction(amountNaira);

    final order = await _createOrder(
      serviceType: VtuServiceType.electricity,
      recipient: meterNumber,
      amountNaira: amountNaira,
      amountSats: amountSats,
      electricityProvider: discoCode,
      meterType: meterType,
    );

    try {
      await updateOrderStatus(order.id, VtuOrderStatus.processing);
      
      debugPrint(
        '🚀 Delivery First: Attempting Electricity API call for ${order.id}',
      );
      final apiResponse = await VtuApiService.buyElectricity(
        meterNumber: meterNumber,
        discoCode: discoCode,
        meterType: meterType,
        amount: amountNaira.toInt(),
        phone: formatPhoneNumber(phone),
      );

      if (apiResponse.success) {
        debugPrint('✅ Delivery Successful. Charging user...');

        try {
          await _payToAgent(
            amountSats,
            'Electricity: ₦${amountNaira.toInt()} to $meterNumber',
          );

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.token ?? apiResponse.transactionId,
          );
          return completedOrder!;

        } catch (paymentError) {
          debugPrint('⚠️ Payment to agent failed after delivery: $paymentError');

          await PaymentRetryService.enqueue(
            orderId: order.id,
            sats: amountSats,
            memo: 'Electricity: ₦${amountNaira.toInt()} to $meterNumber',
            lnAddress: VtuConfig.lightningAddress,
          );

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.token ?? apiResponse.transactionId,
            errorMessage: 'Delivery successful — settlement pending (will retry in background).',
          );
          return completedOrder!;
        }
      } else {
        await updateOrderStatus(
          order.id,
          VtuOrderStatus.failed,
          errorMessage: apiResponse.message,
        );
        throw VtuDeliveryException(
          apiResponse.message,
          errorType: apiResponse.errorType,
          isRecoverable: apiResponse.isRecoverable,
        );
      }
    } catch (e) {
      if (e is InsufficientBalanceException ||
          e is VtuDeliveryException ||
          e is PaymentFailedException) {
        rethrow;
      }
      await updateOrderStatus(
        order.id,
        VtuOrderStatus.failed,
        errorMessage: e.toString(),
      );
      throw VtuServiceException(e.toString());
    }
  }

  /// Process cable TV subscription purchase
  static Future<VtuOrder> processCableTvPurchase({
    required String smartcardNumber,
    required String providerCode,
    required String variationId,
    required double amountNaira,
    required String planName,
    required String phone,
  }) async {
    final amountSats = await nairaToSats(amountNaira);

    // Step 1: Deep Validation
    await validateTransaction(amountNaira);

    final order = await _createOrder(
      serviceType: VtuServiceType.cableTv,
      recipient: smartcardNumber,
      amountNaira: amountNaira,
      amountSats: amountSats,
      cableTvProvider: providerCode,
      cableTvPlanId: variationId,
    );

    try {
      await updateOrderStatus(order.id, VtuOrderStatus.processing);

      debugPrint(
        '🚀 Delivery First: Attempting Cable TV API call for ${order.id}',
      );
      final apiResponse = await VtuApiService.buyCableTv(
        smartcardNumber: smartcardNumber,
        providerCode: providerCode,
        variationId: variationId,
        phone: formatPhoneNumber(phone),
      );

      if (apiResponse.success) {
        debugPrint('✅ Delivery Successful. Charging user...');

        try {
          await _payToAgent(
            amountSats,
            'Cable TV: $planName to $smartcardNumber',
          );

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
          );
          return completedOrder!;

        } catch (paymentError) {
          debugPrint('⚠️ Payment to agent failed after delivery: $paymentError');

          await PaymentRetryService.enqueue(
            orderId: order.id,
            sats: amountSats,
            memo: 'Cable TV: $planName to $smartcardNumber',
            lnAddress: VtuConfig.lightningAddress,
          );

          final completedOrder = await updateOrderStatus(
            order.id,
            VtuOrderStatus.completed,
            token: apiResponse.transactionId,
            errorMessage: 'Delivery successful — settlement pending (will retry in background).',
          );
          return completedOrder!;
        }
      } else {
        await updateOrderStatus(
          order.id,
          VtuOrderStatus.failed,
          errorMessage: apiResponse.message,
        );
        throw VtuDeliveryException(
          apiResponse.message,
          errorType: apiResponse.errorType,
          isRecoverable: apiResponse.isRecoverable,
        );
      }
    } catch (e) {
      if (e is InsufficientBalanceException ||
          e is VtuDeliveryException ||
          e is PaymentFailedException) {
        rethrow;
      }
      await updateOrderStatus(
        order.id,
        VtuOrderStatus.failed,
        errorMessage: e.toString(),
      );
      throw VtuServiceException(e.toString());
    }
  }

  /// Pay to agent's Lightning address
  static Future<void> _payToAgent(int sats, String memo) async {
    try {
      debugPrint('⚡ Paying $sats sats to agent: ${VtuConfig.lightningAddress}');

      // Resolve Lightning address to invoice
      final invoice = await LnAddressService.fetchInvoice(
        lnAddress: VtuConfig.lightningAddress,
        sats: sats,
        memo: memo,
      );

      // Send payment via Breez SDK
      await BreezSparkService.sendPayment(invoice, sats: sats);
      
      // Send push notification for successful VTU payment
      BreezWebhookBridgeService().sendOutgoingPaymentNotification(
        amountSats: sats,
        recipientName: 'VTU Agent',
        description: memo,
      );

      debugPrint('✅ Agent payment successful');
    } catch (e) {
      debugPrint('❌ Agent payment failed: $e');
      
      // Send push notification for failed VTU payment
      BreezWebhookBridgeService().sendPaymentFailedNotification(
        amountSats: sats,
        errorMessage: e.toString(),
        recipientName: 'VTU Agent',
      );
      
      throw PaymentFailedException(e.toString());
    }
  }

  /// Save phone number to recent contacts for quick access
  static Future<void> _saveToRecentContacts(String phone, String label) async {
    try {
      final formattedPhone = formatPhoneNumber(phone);
      await ContactService.addRecentContact(
        ContactInfo(
          displayName: label,
          identifier: formattedPhone,
          type: 'phone',
        ),
      );
      debugPrint('✅ Saved to recent contacts: $formattedPhone');
    } catch (e) {
      // Don't fail the purchase if contact save fails
      debugPrint('⚠️ Failed to save to recent contacts: $e');
    }
  }

  /// Create a new VTU order (internal)
  static Future<VtuOrder> _createOrder({
    required VtuServiceType serviceType,
    required String recipient,
    required double amountNaira,
    required int amountSats,
    String? networkCode,
    String? dataPlanId,
    String? electricityProvider,
    String? meterType,
    String? cableTvProvider,
    String? cableTvPlanId,
  }) async {
    final box = await _openOrdersBox();

    final order = VtuOrder(
      id: _uuid.v4(),
      serviceType: serviceType,
      recipient: recipient,
      amountNaira: amountNaira,
      amountSats: amountSats,
      status: VtuOrderStatus.pending,
      createdAt: DateTime.now(),
      networkCode: networkCode,
      dataPlanId: dataPlanId,
      electricityProvider: electricityProvider,
      meterType: meterType,
      cableTvProvider: cableTvProvider,
      cableTvPlanId: cableTvPlanId,
    );

    await box.put(order.id, jsonEncode(order.toJson()));
    debugPrint('📝 VTU Order created: ${order.id}');
    return order;
  }

  /// Legacy method for provider compatibility
  static Future<VtuOrder> createOrder({
    required VtuServiceType serviceType,
    required String recipient,
    required double amountNaira,
    String? networkCode,
    String? dataPlanId,
    String? electricityProvider,
    String? meterType,
  }) async {
    final amountSats = await nairaToSats(amountNaira);
    return _createOrder(
      serviceType: serviceType,
      recipient: recipient,
      amountNaira: amountNaira,
      amountSats: amountSats,
      networkCode: networkCode,
      dataPlanId: dataPlanId,
      electricityProvider: electricityProvider,
      meterType: meterType,
    );
  }

  /// Update order status
  static Future<VtuOrder?> updateOrderStatus(
    String orderId,
    VtuOrderStatus status, {
    String? token,
    String? errorMessage,
  }) async {
    final box = await _openOrdersBox();
    final orderJson = box.get(orderId);

    if (orderJson == null) return null;

    final order = VtuOrder.fromJson(jsonDecode(orderJson));
    final updatedOrder = order.copyWith(
      status: status,
      completedAt: status == VtuOrderStatus.completed ? DateTime.now() : null,
      token: token,
      errorMessage: errorMessage,
    );

    await box.put(orderId, jsonEncode(updatedOrder.toJson()));
    debugPrint('📝 VTU Order updated: $orderId -> ${status.name}');
    return updatedOrder;
  }

  /// Get all orders
  static Future<List<VtuOrder>> getAllOrders() async {
    final box = await _openOrdersBox();
    final orders = <VtuOrder>[];

    for (final key in box.keys) {
      final orderJson = box.get(key);
      if (orderJson != null) {
        try {
          orders.add(VtuOrder.fromJson(jsonDecode(orderJson)));
        } catch (e) {
          debugPrint('Error parsing order $key: $e');
        }
      }
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Get order by ID
  static Future<VtuOrder?> getOrder(String orderId) async {
    final box = await _openOrdersBox();
    final orderJson = box.get(orderId);

    if (orderJson == null) return null;
    return VtuOrder.fromJson(jsonDecode(orderJson));
  }

  /// Format phone number (remove spaces, ensure starts with 0)
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('234') && cleaned.length == 13) {
      cleaned = '0${cleaned.substring(3)}';
    }

    return cleaned;
  }

  /// Validate Nigerian phone number
  static bool isValidNigerianPhone(String phone) {
    final cleaned = formatPhoneNumber(phone);
    return cleaned.length == 11 && cleaned.startsWith('0');
  }

  /// Validate meter number
  static bool isValidMeterNumber(String meter) {
    final cleaned = meter.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length >= 11 && cleaned.length <= 13;
  }

  /// Verify meter with VTU.ng
  static Future<VtuMeterInfo?> verifyMeter({
    required String meterNumber,
    required String discoCode,
    required String meterType,
  }) async {
    return await VtuApiService.verifyMeter(
      meterNumber: meterNumber,
      discoCode: discoCode,
      meterType: meterType,
    );
  }

  /// Get live data plans from VTU.ng
  static Future<List<DataPlan>> getLiveDataPlans(
    NetworkProvider network,
  ) async {
    try {
      final vtuPlans = await VtuApiService.getDataPlans(network.code);
      return vtuPlans.map((p) => p.toDataPlan(network)).toList();
    } catch (e) {
      debugPrint('⚠️ Failed to fetch live plans, using hardcoded: $e');
      // Fallback to hardcoded plans
      return DataPlan.getPlansForNetwork(network);
    }
  }

  /// Check VTU.ng agent balance
  static Future<VtuBalanceInfo> getAgentBalance() async {
    return await VtuApiService.getBalance();
  }

  /// Check if VTU.ng has sufficient liquidity
  static Future<bool> hasVtuLiquidity(double amountNaira) async {
    try {
      final balance = await VtuApiService.getBalance();
      // Add 10% buffer for safety
      return balance.balance >= (amountNaira * 1.1);
    } catch (e) {
      debugPrint('⚠️ Could not check VTU.ng balance: $e');
      // Assume available if we can't check
      return true;
    }
  }

  /// Verify cable TV customer (smartcard number)
  static Future<VtuCableTvCustomerInfo?> verifyCableTvCustomer({
    required String smartcardNumber,
    required String providerCode,
  }) async {
    return await VtuApiService.verifyCableTvCustomer(
      smartcardNumber: smartcardNumber,
      providerCode: providerCode,
    );
  }

  /// Get live cable TV plans from VTU.ng
  static Future<List<VtuCableTvPlan>> getCableTvPlans(
    String providerCode,
  ) async {
    try {
      return await VtuApiService.getCableTvPlans(providerCode);
    } catch (e) {
      debugPrint('⚠️ Failed to fetch cable TV plans: $e');
      return [];
    }
  }

  /// Validate smartcard number (typically 10-11 digits)
  static bool isValidSmartcardNumber(String smartcard) {
    final cleaned = smartcard.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length >= 10 && cleaned.length <= 11;
  }

  // ============================================================================
  // REFUND SYSTEM
  // ============================================================================

  /// Request a refund for a failed order
  /// Generates a Lightning invoice for the refund amount
  /// Agent will pay this invoice to complete the refund
  static Future<VtuOrder?> requestRefund(String orderId) async {
    final order = await getOrder(orderId);
    if (order == null) {
      throw RefundException('Order not found');
    }

    // Validate order is eligible for refund
    if (!order.canRequestRefund) {
      if (order.status != VtuOrderStatus.failed) {
        throw RefundException('Only failed orders can be refunded');
      }
      if (order.refundStatus != RefundStatus.none) {
        throw RefundException('Refund already ${order.refundStatus.name.toLowerCase()}');
      }
    }

    try {
      debugPrint('💰 Requesting refund for order: $orderId');
      debugPrint('   Amount: ${order.amountSats} sats');

      // Generate Lightning invoice for the refund amount
      final invoice = await BreezSparkService.createInvoice(
        sats: order.amountSats,
        memo: 'Refund: ${order.serviceName} - ${order.recipient}',
      );

      // Update order with refund info
      final box = await _openOrdersBox();
      final updatedOrder = order.copyWith(
        refundStatus: RefundStatus.requested,
        refundInvoice: invoice,
        refundRequestedAt: DateTime.now(),
      );

      await box.put(orderId, jsonEncode(updatedOrder.toJson()));
      debugPrint('✅ Refund requested - invoice generated');

      return updatedOrder;
    } catch (e) {
      debugPrint('❌ Refund request failed: $e');
      throw RefundException('Failed to generate refund invoice: $e');
    }
  }

  /// Mark a refund as completed (called when payment is received)
  static Future<VtuOrder?> markRefundCompleted(String orderId) async {
    final order = await getOrder(orderId);
    if (order == null) return null;

    if (order.refundStatus != RefundStatus.requested) {
      throw RefundException('No pending refund for this order');
    }

    final box = await _openOrdersBox();
    final updatedOrder = order.copyWith(
      status: VtuOrderStatus.refunded,
      refundStatus: RefundStatus.completed,
      refundCompletedAt: DateTime.now(),
    );

    await box.put(orderId, jsonEncode(updatedOrder.toJson()));
    debugPrint('✅ Refund completed for order: $orderId');

    return updatedOrder;
  }

  /// Get orders that have pending refunds
  static Future<List<VtuOrder>> getOrdersWithPendingRefunds() async {
    final allOrders = await getAllOrders();
    return allOrders.where((o) => o.hasRefundPending).toList();
  }

  /// Cancel a refund request (before it's paid)
  static Future<VtuOrder?> cancelRefundRequest(String orderId) async {
    final order = await getOrder(orderId);
    if (order == null) return null;

    if (order.refundStatus != RefundStatus.requested) {
      throw RefundException('No pending refund to cancel');
    }

    final box = await _openOrdersBox();
    final updatedOrder = VtuOrder(
      id: order.id,
      serviceType: order.serviceType,
      recipient: order.recipient,
      amountNaira: order.amountNaira,
      amountSats: order.amountSats,
      status: order.status,
      createdAt: order.createdAt,
      completedAt: order.completedAt,
      networkCode: order.networkCode,
      dataPlanId: order.dataPlanId,
      electricityProvider: order.electricityProvider,
      meterType: order.meterType,
      token: order.token,
      cableTvProvider: order.cableTvProvider,
      cableTvPlanId: order.cableTvPlanId,
      errorMessage: order.errorMessage,
      refundStatus: RefundStatus.none,
      refundInvoice: null,
      refundRequestedAt: null,
      refundCompletedAt: null,
    );

    await box.put(orderId, jsonEncode(updatedOrder.toJson()));
    debugPrint('🚫 Refund request cancelled for order: $orderId');

    return updatedOrder;
  }
}

/// Exception for insufficient Lightning balance
class InsufficientBalanceException implements Exception {
  final int required;
  final int available;

  InsufficientBalanceException({
    required this.required,
    required this.available,
  });

  int get shortfall => required - available;

  @override
  String toString() =>
      'Insufficient balance: need $required sats, have $available sats';
}

/// Exception for payment failure
class PaymentFailedException implements Exception {
  final String message;
  PaymentFailedException(this.message);

  @override
  String toString() => 'Payment failed: $message';
}

/// Exception for VTU delivery failure (payment was made but delivery failed)
class VtuDeliveryException implements Exception {
  final String message;
  final VtuErrorType? errorType;
  final bool isRecoverable;

  VtuDeliveryException(
    this.message, {
    this.errorType,
    this.isRecoverable = false,
  });

  /// Check if this is a VTU.ng liquidity issue
  bool get isVtuLiquidityIssue =>
      errorType == VtuErrorType.vtuInsufficientFunds ||
      errorType == VtuErrorType.vtuWalletError;

  /// Check if this is a network/service issue
  bool get isServiceUnavailable =>
      errorType == VtuErrorType.serviceUnavailable ||
      errorType == VtuErrorType.networkError;

  @override
  String toString() => 'VTU delivery failed: $message';
}

/// Exception for network/connectivity errors
class VtuNetworkException implements Exception {
  final String message;
  VtuNetworkException(this.message);

  @override
  String toString() => 'Network error: $message';
}

/// Exception for refund errors
class RefundException implements Exception {
  final String message;
  RefundException(this.message);

  @override
  String toString() => 'Refund error: $message';
}

/// Exception for general VTU service errors
class VtuServiceException implements Exception {
  final String message;
  const VtuServiceException(this.message);
  @override
  String toString() => message;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';

/// Provider for VTU orders list
final vtuOrdersProvider = StateNotifierProvider<VtuOrdersNotifier, AsyncValue<List<VtuOrder>>>((ref) {
  return VtuOrdersNotifier();
});

class VtuOrdersNotifier extends StateNotifier<AsyncValue<List<VtuOrder>>> {
  VtuOrdersNotifier() : super(const AsyncValue.loading()) {
    loadOrders();
  }

  Future<void> loadOrders() async {
    state = const AsyncValue.loading();
    try {
      final orders = await VtuService.getAllOrders();
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadOrders();
  }

  Future<VtuOrder> createOrder({
    required VtuServiceType serviceType,
    required String recipient,
    required double amountNaira,
    String? networkCode,
    String? dataPlanId,
    String? electricityProvider,
    String? meterType,
  }) async {
    final order = await VtuService.createOrder(
      serviceType: serviceType,
      recipient: recipient,
      amountNaira: amountNaira,
      networkCode: networkCode,
      dataPlanId: dataPlanId,
      electricityProvider: electricityProvider,
      meterType: meterType,
    );
    await loadOrders();
    return order;
  }

  Future<void> markProcessing(String orderId) async {
    await VtuService.updateOrderStatus(orderId, VtuOrderStatus.processing);
    await loadOrders();
  }

  Future<void> markCompleted(String orderId, {String? token}) async {
    await VtuService.updateOrderStatus(orderId, VtuOrderStatus.completed, token: token);
    await loadOrders();
  }

  Future<void> markFailed(String orderId, String errorMessage) async {
    await VtuService.updateOrderStatus(orderId, VtuOrderStatus.failed, errorMessage: errorMessage);
    await loadOrders();
  }
}

/// Provider for selected network
final selectedNetworkProvider = StateProvider<NetworkProvider?>((ref) => null);

/// Provider for selected electricity provider
final selectedElectricityProvider = StateProvider<ElectricityProvider?>((ref) => null);

/// Provider for selected meter type
final selectedMeterTypeProvider = StateProvider<MeterType>((ref) => MeterType.prepaid);

/// Provider for phone number input
final phoneNumberProvider = StateProvider<String>((ref) => '');

/// Provider for meter number input
final meterNumberProvider = StateProvider<String>((ref) => '');

/// Provider for selected airtime amount
final selectedAirtimeAmountProvider = StateProvider<double?>((ref) => null);

/// Provider for selected data plan
final selectedDataPlanProvider = StateProvider<DataPlan?>((ref) => null);

/// Provider for selected electricity amount
final selectedElectricityAmountProvider = StateProvider<double?>((ref) => null);

/// Provider to convert Naira to Sats
final nairaToSatsProvider = FutureProvider.family<int, double>((ref, naira) async {
  return await VtuService.nairaToSats(naira);
});

/// Provider to get data plans for selected network
final dataPlansProvider = Provider<List<DataPlan>>((ref) {
  final network = ref.watch(selectedNetworkProvider);
  if (network == null) return [];
  return DataPlan.getPlansForNetwork(network);
});

/// Provider for pending orders count
final pendingOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(vtuOrdersProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.where((o) => 
      o.status == VtuOrderStatus.pending || 
      o.status == VtuOrderStatus.processing
    ).length,
    orElse: () => 0,
  );
});

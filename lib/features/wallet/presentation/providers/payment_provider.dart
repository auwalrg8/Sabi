import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Provider for payment history from Spark SDK
final paymentHistoryProvider = StreamProvider<List<PaymentRecord>>((ref) {
  return BreezSparkService.paymentStream.map((event) => [event]);
});

/// Provider for latest payments (cached list)
final latestPaymentsProvider = FutureProvider<List<PaymentRecord>>((
  ref,
) async {
  return BreezSparkService.listPaymentDetails();
});

/// Provider for all payments (complete history)
final allPaymentsProvider = FutureProvider<List<PaymentRecord>>((ref) async {
  return BreezSparkService.listPaymentDetails();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

final pendingPaymentsProvider = StreamProvider<List<PendingPaymentRecord>>((
  ref,
) {
  return BreezSparkService.pendingPaymentsStream;
});

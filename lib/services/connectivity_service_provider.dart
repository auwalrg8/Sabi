import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();

  service.init(
    backendUrl: 'https://api.sabi.money',
    interval: const Duration(seconds: 30),
  );

  ref.onDispose(service.dispose);
  return service;
});

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  return ref.watch(connectivityServiceProvider).connectionStream;
});

final backendStatusProvider = StreamProvider<BackendStatus>((ref) {
  return ref.watch(connectivityServiceProvider).backendStream;
});

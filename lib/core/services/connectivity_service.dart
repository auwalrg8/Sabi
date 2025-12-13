import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  ConnectivityService();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _connectionCtrl = StreamController<ConnectionStatus>.broadcast();
  final _backendCtrl = StreamController<BackendStatus>.broadcast();

  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;
  BackendStatus _backendStatus = BackendStatus.unknown;

  String? _backendUrl;
  Duration _interval = const Duration(seconds: 30);
  Timer? _timer;
  DateTime? _lastBackendCheck;

  Stream<ConnectionStatus> get connectionStream => _connectionCtrl.stream;
  Stream<BackendStatus> get backendStream => _backendCtrl.stream;

  bool get isConnected => _connectionStatus == ConnectionStatus.connected;

  Future<void> init({required String backendUrl, Duration? interval}) async {
    _backendUrl = backendUrl;
    if (interval != null) _interval = interval;

    await _updateConnection();

    _subscription = _connectivity.onConnectivityChanged.listen(
      (_) => _updateConnection(),
      onError: (e) => debugPrint('Connectivity error: $e'),
    );

    _startBackendChecks();
  }

  Future<void> _updateConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      final next =
          hasConnection
              ? ConnectionStatus.connected
              : ConnectionStatus.disconnected;

      if (next != _connectionStatus) {
        _connectionStatus = next;
        _connectionCtrl.add(next);

        if (next == ConnectionStatus.connected) {
          await _checkBackend();
        } else {
          _setBackendStatus(BackendStatus.unknown);
        }
      }
    } catch (_) {
      _connectionCtrl.add(ConnectionStatus.unknown);
    }
  }

  void _startBackendChecks() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (isConnected) _checkBackend();
    });
  }

  Future<void> _checkBackend() async {
    if (!isConnected || _backendUrl == null) return;

    final now = DateTime.now();
    if (_lastBackendCheck != null &&
        now.difference(_lastBackendCheck!) < const Duration(seconds: 10)) {
      return;
    }
    _lastBackendCheck = now;

    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/health/breez'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _setBackendStatus(BackendStatus.available);
      } else {
        _setBackendStatus(BackendStatus.error);
      }
    } on TimeoutException {
      _setBackendStatus(BackendStatus.timeout);
    } catch (_) {
      _setBackendStatus(BackendStatus.unavailable);
    }
  }

  void _setBackendStatus(BackendStatus status) {
    if (status != _backendStatus) {
      _backendStatus = status;
      _backendCtrl.add(status);
    }
  }

  Future<void> retry() async {
    await _updateConnection();
    if (isConnected) await _checkBackend();
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _connectionCtrl.close();
    _backendCtrl.close();
  }
}

enum ConnectionStatus { connected, disconnected, unknown }

enum BackendStatus { available, unavailable, timeout, error, unknown }

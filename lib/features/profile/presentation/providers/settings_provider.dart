import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

class SettingsState {
  final bool biometricEnabled;
  final String currency;
  final String transactionLimit;
  final String language;
  final bool notificationsEnabled;
  final String networkFee;

  SettingsState({
    this.biometricEnabled = false,
    this.currency = 'NGN',
    this.transactionLimit = '₦100,000',
    this.language = 'English',
    this.notificationsEnabled = true,
    this.networkFee = 'Economy',
  });

  SettingsState copyWith({
    bool? biometricEnabled,
    String? currency,
    String? transactionLimit,
    String? language,
    bool? notificationsEnabled,
    String? networkFee,
  }) {
    return SettingsState(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      currency: currency ?? this.currency,
      transactionLimit: transactionLimit ?? this.transactionLimit,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      networkFee: networkFee ?? this.networkFee,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SecureStorageService _storage;

  SettingsNotifier(this._storage) : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometric = await _storage.read(key: 'biometric_enabled') == 'true';
    final currency = await _storage.read(key: 'currency') ?? 'NGN';
    final transactionLimit =
        await _storage.read(key: 'transaction_limit') ?? '₦100,000';
    final language = await _storage.read(key: 'language') ?? 'English';
    final notifications =
        await _storage.read(key: 'notifications_enabled') != 'false';
    final networkFee = await _storage.read(key: 'network_fee') ?? 'Economy';

    state = SettingsState(
      biometricEnabled: biometric,
      currency: currency,
      transactionLimit: transactionLimit,
      language: language,
      notificationsEnabled: notifications,
      networkFee: networkFee,
    );
  }

  Future<void> toggleBiometric(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setCurrency(String currency) async {
    await _storage.write(key: 'currency', value: currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> setTransactionLimit(String limit) async {
    await _storage.write(key: 'transaction_limit', value: limit);
    state = state.copyWith(transactionLimit: limit);
  }

  Future<void> setLanguage(String language) async {
    await _storage.write(key: 'language', value: language);
    state = state.copyWith(language: language);
  }

  Future<void> toggleNotifications(bool enabled) async {
    await _storage.write(
      key: 'notifications_enabled',
      value: enabled.toString(),
    );
    state = state.copyWith(notificationsEnabled: enabled);
  }

  Future<void> setNetworkFee(String fee) async {
    await _storage.write(key: 'network_fee', value: fee);
    state = state.copyWith(networkFee: fee);
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
      final storage = ref.watch(secureStorageServiceProvider);
      return SettingsNotifier(storage);
    });

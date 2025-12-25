import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/app_state_service.dart';

/// Enum for suggestion types
enum SuggestionType { backup, nostr, pin, socialRecovery }

/// Provider for the list of visible suggestion cards
final suggestionsProvider = StateNotifierProvider<SuggestionsNotifier, List<SuggestionType>>((ref) {
  final storage = ref.read(secureStorageServiceProvider);
  return SuggestionsNotifier(storage);
});

class SuggestionsNotifier extends StateNotifier<List<SuggestionType>> {
  static const _storageKey = 'dismissed_suggestions';
  final SecureStorageService _storage;
  bool _initialized = false;

  SuggestionsNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    if (_initialized) return;
    // First, compute which suggestions should be shown based on stored user state
    final backupStatus = await _storage.getBackupStatus(); // null when not set
    final npub = await _storage.getNostrPublicKey();
    final hasPin = await _storage.hasPinCode();

    final shouldShowBackup = backupStatus == null && AppStateService.hasWallet;
    final shouldShowNostr = npub == null || npub.isEmpty;
    final shouldShowPin = !hasPin && AppStateService.hasWallet;
    
    // Show social recovery suggestion if user backed up with seed phrase but not social recovery
    final hasSocialRecovery = await _storage.read(key: 'social_recovery_setup') == 'true';
    final shouldShowSocialRecovery = backupStatus == 'seed_phrase' && !hasSocialRecovery && AppStateService.hasWallet;

    final candidates = <SuggestionType>[];
    if (shouldShowBackup) candidates.add(SuggestionType.backup);
    if (shouldShowSocialRecovery) candidates.add(SuggestionType.socialRecovery);
    if (shouldShowNostr) candidates.add(SuggestionType.nostr);
    if (shouldShowPin) candidates.add(SuggestionType.pin);

    // Respect previously dismissed items persisted in secure storage
    final dismissed = await _storage.read(key: _storageKey);
    if (dismissed == 'all') {
      state = [];
    } else if (dismissed != null && dismissed.isNotEmpty) {
      final ids = dismissed.split(',').map((e) => e.trim()).toSet();
      state = candidates.where((c) => !ids.contains(c.name)).toList();
    } else {
      state = candidates;
    }

    _initialized = true;
  }

  Future<void> dismiss(SuggestionType type) async {
    final newState = List<SuggestionType>.from(state)..remove(type);
    state = newState;
    if (newState.isEmpty) {
      await _storage.write(key: _storageKey, value: 'all');
    } else {
      final dismissed = SuggestionType.values.where((e) => !newState.contains(e)).map((e) => e.name).join(',');
      await _storage.write(key: _storageKey, value: dismissed);
    }
  }

  /// For onboarding/new user, reset suggestions
  Future<void> reset() async {
    await _storage.delete(key: _storageKey);
    state = SuggestionType.values.toList();
  }
}

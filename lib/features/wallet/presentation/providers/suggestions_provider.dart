import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

/// Suggestion types for the home screen slider
enum SuggestionCardType { backup, nostr, pin }

/// Provider for the list of visible suggestion cards
final suggestionsProvider = StateNotifierProvider<SuggestionsNotifier, List<SuggestionCardType>>((ref) {
  return SuggestionsNotifier(ref.read(secureStorageServiceProvider));
});

class SuggestionsNotifier extends StateNotifier<List<SuggestionCardType>> {
  static const _storageKey = 'dismissed_suggestions';
  final SecureStorageService _storage;
  bool _initialized = false;

  SuggestionsNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    if (_initialized) return;
    final dismissed = await _storage.read(key: _storageKey);
    if (dismissed == 'all') {
      state = [];
    } else if (dismissed != null) {
      final ids = dismissed.split(',').map((e) => e.trim()).toSet();
      state = SuggestionCardType.values.where((e) => !ids.contains(e.name)).toList();
    } else {
      state = SuggestionCardType.values.toList();
    }
    _initialized = true;
  }

  Future<void> dismiss(SuggestionCardType type) async {
    final newState = List<SuggestionCardType>.from(state)..remove(type);
    state = newState;
    if (newState.isEmpty) {
      await _storage.write(key: _storageKey, value: 'all');
    } else {
      final dismissed = SuggestionCardType.values.where((e) => !newState.contains(e)).map((e) => e.name).join(',');
      await _storage.write(key: _storageKey, value: dismissed);
    }
  }

  /// For onboarding/new user, reset suggestions
  Future<void> reset() async {
    await _storage.delete(key: _storageKey);
    state = SuggestionCardType.values.toList();
  }
}

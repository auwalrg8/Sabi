import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/l10n/localization.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

class LanguageNotifier extends StateNotifier<Locale> {
  final SecureStorageService _storage;

  LanguageNotifier(this._storage) : super(const Locale('en')) {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final savedLanguage = await _storage.read(key: 'language') ?? 'English';
    final localeCode = Localization.getLocaleCode(savedLanguage);
    state = Localization.getLocale(localeCode);
  }

  Future<void> setLanguage(String displayName) async {
    await _storage.write(key: 'language', value: displayName);
    final localeCode = Localization.getLocaleCode(displayName);
    state = Localization.getLocale(localeCode);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final displayName = Localization.getDisplayName(locale.languageCode);
    await _storage.write(key: 'language', value: displayName);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier(SecureStorageService());
});

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';

class Localization {
  static const all = [
    Locale('en'),  // English
    Locale('ha'),  // Hausa
    Locale('yo'),  // Yoruba
    Locale('pcm'), // Pidgin (Nigerian Creole - ISO 639-3 code)
  ];

  static const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = all;

  /// Convert display name to locale code
  static String getLocaleCode(String displayName) {
    switch (displayName) {
      case 'English':
        return 'en';
      case 'Hausa':
        return 'ha';
      case 'Yoruba':
        return 'yo';
      case 'Pidgin':
        return 'pcm';
      default:
        return 'en';
    }
  }

  /// Convert locale code to display name
  static String getDisplayName(String localeCode) {
    switch (localeCode) {
      case 'en':
        return 'English';
      case 'ha':
        return 'Hausa';
      case 'yo':
        return 'Yoruba';
      case 'pcm':
        return 'Pidgin';
      default:
        return 'English';
    }
  }

  /// Get locale from code
  static Locale getLocale(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'ha':
        return const Locale('ha');
      case 'yo':
        return const Locale('yo');
      case 'pcm':
        return const Locale('pcm');
      default:
        return const Locale('en');
    }
  }
}

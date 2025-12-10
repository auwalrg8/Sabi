import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';

class Localization {
  static const all = [
    Locale('en'), // English
    Locale('ha'), // Hausa
    Locale('yo'), // Yoruba
    Locale('pcm'), // Pidgin (Nigerian Creole - ISO 639-3 code)
  ];

  static const List<LocalizationsDelegate<dynamic>> delegates = [
    AppLocalizations.delegate,
    FallbackMaterialLocalizationsDelegate(),
    FallbackWidgetsLocalizationsDelegate(),
    FallbackCupertinoLocalizationsDelegate(),
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

Locale _resolveFallbackLocale(
  Locale locale,
  LocalizationsDelegate<dynamic> delegate,
) {
  if (delegate.isSupported(locale)) {
    return locale;
  }

  return const Locale('en');
}

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final resolvedLocale = _resolveFallbackLocale(
      locale,
      GlobalMaterialLocalizations.delegate,
    );
    return GlobalMaterialLocalizations.delegate.load(resolvedLocale);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final resolvedLocale = _resolveFallbackLocale(
      locale,
      GlobalWidgetsLocalizations.delegate,
    );
    return GlobalWidgetsLocalizations.delegate.load(resolvedLocale);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final resolvedLocale = _resolveFallbackLocale(
      locale,
      GlobalCupertinoLocalizations.delegate,
    );
    return GlobalCupertinoLocalizations.delegate.load(resolvedLocale);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) => false;
}

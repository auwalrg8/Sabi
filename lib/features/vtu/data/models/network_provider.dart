/// Mobile network operators in Nigeria
enum NetworkProvider {
  mtn,
  glo,
  airtel,
  nineMobile,
}

extension NetworkProviderExtension on NetworkProvider {
  String get name {
    switch (this) {
      case NetworkProvider.mtn:
        return 'MTN';
      case NetworkProvider.glo:
        return 'Glo';
      case NetworkProvider.airtel:
        return 'Airtel';
      case NetworkProvider.nineMobile:
        return '9mobile';
    }
  }

  String get code {
    switch (this) {
      case NetworkProvider.mtn:
        return 'mtn';
      case NetworkProvider.glo:
        return 'glo';
      case NetworkProvider.airtel:
        return 'airtel';
      case NetworkProvider.nineMobile:
        return 'etisalat';
    }
  }

  String get logo {
    switch (this) {
      case NetworkProvider.mtn:
        return 'assets/icons/vtu/mtn.png';
      case NetworkProvider.glo:
        return 'assets/icons/vtu/glo.png';
      case NetworkProvider.airtel:
        return 'assets/icons/vtu/airtel.png';
      case NetworkProvider.nineMobile:
        return 'assets/icons/vtu/9mobile.png';
    }
  }

  int get primaryColor {
    switch (this) {
      case NetworkProvider.mtn:
        return 0xFFFFCC00; // Yellow
      case NetworkProvider.glo:
        return 0xFF50B651; // Green
      case NetworkProvider.airtel:
        return 0xFFE40000; // Red
      case NetworkProvider.nineMobile:
        return 0xFF006B53; // Dark green
    }
  }

  /// Prefix patterns for auto-detection
  List<String> get prefixes {
    switch (this) {
      case NetworkProvider.mtn:
        return ['0803', '0806', '0703', '0706', '0813', '0816', '0810', '0814', '0903', '0906', '0913', '0916'];
      case NetworkProvider.glo:
        return ['0805', '0807', '0705', '0815', '0811', '0905', '0915'];
      case NetworkProvider.airtel:
        return ['0802', '0808', '0708', '0812', '0701', '0902', '0901', '0907', '0912'];
      case NetworkProvider.nineMobile:
        return ['0809', '0817', '0818', '0908', '0909'];
    }
  }

  static NetworkProvider? detectFromPhone(String phone) {
    if (phone.length < 4) return null;
    
    final prefix = phone.substring(0, 4);
    
    for (final provider in NetworkProvider.values) {
      if (provider.prefixes.contains(prefix)) {
        return provider;
      }
    }
    return null;
  }
}

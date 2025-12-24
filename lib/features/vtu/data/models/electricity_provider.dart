/// Electricity distribution companies in Nigeria
enum ElectricityProvider {
  ikedc,
  ekedc,
  aedc,
  phedc,
  kedco,
  ibedc,
  bedc,
  jedc,
  kaedco,
  eedc,
}

extension ElectricityProviderExtension on ElectricityProvider {
  String get name {
    switch (this) {
      case ElectricityProvider.ikedc:
        return 'Ikeja Electric';
      case ElectricityProvider.ekedc:
        return 'Eko Electric';
      case ElectricityProvider.aedc:
        return 'Abuja Electric';
      case ElectricityProvider.phedc:
        return 'Port Harcourt Electric';
      case ElectricityProvider.kedco:
        return 'Kano Electric';
      case ElectricityProvider.ibedc:
        return 'Ibadan Electric';
      case ElectricityProvider.bedc:
        return 'Benin Electric';
      case ElectricityProvider.jedc:
        return 'Jos Electric';
      case ElectricityProvider.kaedco:
        return 'Kaduna Electric';
      case ElectricityProvider.eedc:
        return 'Enugu Electric';
    }
  }

  String get code {
    switch (this) {
      case ElectricityProvider.ikedc:
        return 'ikeja-electric';
      case ElectricityProvider.ekedc:
        return 'eko-electric';
      case ElectricityProvider.aedc:
        return 'abuja-electric';
      case ElectricityProvider.phedc:
        return 'portharcourt-electric';
      case ElectricityProvider.kedco:
        return 'kano-electric';
      case ElectricityProvider.ibedc:
        return 'ibadan-electric';
      case ElectricityProvider.bedc:
        return 'benin-electric';
      case ElectricityProvider.jedc:
        return 'jos-electric';
      case ElectricityProvider.kaedco:
        return 'kaduna-electric';
      case ElectricityProvider.eedc:
        return 'enugu-electric';
    }
  }

  String get shortName {
    switch (this) {
      case ElectricityProvider.ikedc:
        return 'IKEDC';
      case ElectricityProvider.ekedc:
        return 'EKEDC';
      case ElectricityProvider.aedc:
        return 'AEDC';
      case ElectricityProvider.phedc:
        return 'PHEDC';
      case ElectricityProvider.kedco:
        return 'KEDCO';
      case ElectricityProvider.ibedc:
        return 'IBEDC';
      case ElectricityProvider.bedc:
        return 'BEDC';
      case ElectricityProvider.jedc:
        return 'JEDC';
      case ElectricityProvider.kaedco:
        return 'KAEDCO';
      case ElectricityProvider.eedc:
        return 'EEDC';
    }
  }

  int get primaryColor {
    switch (this) {
      case ElectricityProvider.ikedc:
        return 0xFF1E88E5; // Blue
      case ElectricityProvider.ekedc:
        return 0xFFE53935; // Red
      case ElectricityProvider.aedc:
        return 0xFF43A047; // Green
      case ElectricityProvider.phedc:
        return 0xFF8E24AA; // Purple
      case ElectricityProvider.kedco:
        return 0xFFFF9800; // Orange
      case ElectricityProvider.ibedc:
        return 0xFF00ACC1; // Cyan
      case ElectricityProvider.bedc:
        return 0xFF5E35B1; // Deep purple
      case ElectricityProvider.jedc:
        return 0xFF00897B; // Teal
      case ElectricityProvider.kaedco:
        return 0xFFC0CA33; // Lime
      case ElectricityProvider.eedc:
        return 0xFF6D4C41; // Brown
    }
  }
}

/// Meter type for electricity purchase
enum MeterType {
  prepaid,
  postpaid,
}

extension MeterTypeExtension on MeterType {
  String get name {
    switch (this) {
      case MeterType.prepaid:
        return 'Prepaid';
      case MeterType.postpaid:
        return 'Postpaid';
    }
  }

  String get code {
    switch (this) {
      case MeterType.prepaid:
        return 'prepaid';
      case MeterType.postpaid:
        return 'postpaid';
    }
  }
}

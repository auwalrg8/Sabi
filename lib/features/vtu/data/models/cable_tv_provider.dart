/// Cable TV providers in Nigeria
enum CableTvProvider {
  dstv,
  gotv,
  startimes,
}

extension CableTvProviderExtension on CableTvProvider {
  String get name {
    switch (this) {
      case CableTvProvider.dstv:
        return 'DStv';
      case CableTvProvider.gotv:
        return 'GOtv';
      case CableTvProvider.startimes:
        return 'Startimes';
    }
  }

  String get code {
    switch (this) {
      case CableTvProvider.dstv:
        return 'dstv';
      case CableTvProvider.gotv:
        return 'gotv';
      case CableTvProvider.startimes:
        return 'startimes';
    }
  }

  String get serviceId {
    switch (this) {
      case CableTvProvider.dstv:
        return 'dstv';
      case CableTvProvider.gotv:
        return 'gotv';
      case CableTvProvider.startimes:
        return 'startimes';
    }
  }

  String get logo {
    switch (this) {
      case CableTvProvider.dstv:
        return '📺'; // Can be replaced with actual asset
      case CableTvProvider.gotv:
        return '📡';
      case CableTvProvider.startimes:
        return '🌟';
    }
  }

  int get primaryColor {
    switch (this) {
      case CableTvProvider.dstv:
        return 0xFF0033A1; // DStv blue
      case CableTvProvider.gotv:
        return 0xFF00A651; // GOtv green
      case CableTvProvider.startimes:
        return 0xFFFF6600; // Startimes orange
    }
  }

  String get description {
    switch (this) {
      case CableTvProvider.dstv:
        return 'Premium satellite TV';
      case CableTvProvider.gotv:
        return 'Digital terrestrial TV';
      case CableTvProvider.startimes:
        return 'Affordable satellite TV';
    }
  }

  static CableTvProvider? fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'dstv':
        return CableTvProvider.dstv;
      case 'gotv':
        return CableTvProvider.gotv;
      case 'startimes':
        return CableTvProvider.startimes;
      default:
        return null;
    }
  }
}

/// Cable TV subscription plan
class CableTvPlan {
  final String variationId;
  final String name;
  final double price;
  final double resellerPrice;
  final CableTvProvider provider;
  final String? description;
  final String? validity;
  final bool isAvailable;

  const CableTvPlan({
    required this.variationId,
    required this.name,
    required this.price,
    required this.resellerPrice,
    required this.provider,
    this.description,
    this.validity,
    this.isAvailable = true,
  });

  /// Profit margin per transaction
  double get profitMargin => price - resellerPrice;

  /// Format price for display
  String get formattedPrice => '₦${price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      )}';
}

/// Customer verification info for Cable TV
class CableTvCustomerInfo {
  final String customerName;
  final String smartcardNumber;
  final String currentBouquet;
  final String? dueDate;
  final double? balance;
  final bool isValid;

  const CableTvCustomerInfo({
    required this.customerName,
    required this.smartcardNumber,
    this.currentBouquet = '',
    this.dueDate,
    this.balance,
    required this.isValid,
  });
}

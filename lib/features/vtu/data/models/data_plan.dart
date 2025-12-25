import 'network_provider.dart';

/// Data plan model for mobile data bundles
class DataPlan {
  final String id;
  final NetworkProvider network;
  final String name;
  final String description;
  final double priceNaira; // Reseller price (our cost)
  final double? retailPrice; // VTU.ng retail price (customer price)
  final String validity;
  final String dataAmount;
  final String? serviceName; // e.g., "MTN SME", "MTN Gifting", etc.

  const DataPlan({
    required this.id,
    required this.network,
    required this.name,
    required this.description,
    required this.priceNaira,
    this.retailPrice,
    required this.validity,
    required this.dataAmount,
    this.serviceName,
  });

  /// Profit margin when selling at retail price
  double get profitMargin => (retailPrice ?? priceNaira) - priceNaira;

  /// Discount percentage from retail
  double get discountPercent {
    if (retailPrice == null || retailPrice == 0) return 0;
    return ((retailPrice! - priceNaira) / retailPrice!) * 100;
  }

  /// Get all available data plans (hardcoded for agent model)
  static List<DataPlan> getPlansForNetwork(NetworkProvider network) {
    switch (network) {
      case NetworkProvider.mtn:
        return _mtnPlans;
      case NetworkProvider.glo:
        return _gloPlans;
      case NetworkProvider.airtel:
        return _airtelPlans;
      case NetworkProvider.nineMobile:
        return _9mobilePlans;
    }
  }

  static const List<DataPlan> _mtnPlans = [
    DataPlan(
      id: 'mtn_500mb',
      network: NetworkProvider.mtn,
      name: '500MB',
      description: 'MTN 500MB Data',
      priceNaira: 150,
      validity: '30 days',
      dataAmount: '500MB',
    ),
    DataPlan(
      id: 'mtn_1gb',
      network: NetworkProvider.mtn,
      name: '1GB',
      description: 'MTN 1GB Data',
      priceNaira: 300,
      validity: '30 days',
      dataAmount: '1GB',
    ),
    DataPlan(
      id: 'mtn_2gb',
      network: NetworkProvider.mtn,
      name: '2GB',
      description: 'MTN 2GB Data',
      priceNaira: 600,
      validity: '30 days',
      dataAmount: '2GB',
    ),
    DataPlan(
      id: 'mtn_3gb',
      network: NetworkProvider.mtn,
      name: '3GB',
      description: 'MTN 3GB Data',
      priceNaira: 900,
      validity: '30 days',
      dataAmount: '3GB',
    ),
    DataPlan(
      id: 'mtn_5gb',
      network: NetworkProvider.mtn,
      name: '5GB',
      description: 'MTN 5GB Data',
      priceNaira: 1500,
      validity: '30 days',
      dataAmount: '5GB',
    ),
    DataPlan(
      id: 'mtn_10gb',
      network: NetworkProvider.mtn,
      name: '10GB',
      description: 'MTN 10GB Data',
      priceNaira: 3000,
      validity: '30 days',
      dataAmount: '10GB',
    ),
  ];

  static const List<DataPlan> _gloPlans = [
    DataPlan(
      id: 'glo_500mb',
      network: NetworkProvider.glo,
      name: '500MB',
      description: 'Glo 500MB Data',
      priceNaira: 150,
      validity: '30 days',
      dataAmount: '500MB',
    ),
    DataPlan(
      id: 'glo_1gb',
      network: NetworkProvider.glo,
      name: '1GB',
      description: 'Glo 1GB Data',
      priceNaira: 300,
      validity: '30 days',
      dataAmount: '1GB',
    ),
    DataPlan(
      id: 'glo_2gb',
      network: NetworkProvider.glo,
      name: '2GB',
      description: 'Glo 2GB Data',
      priceNaira: 600,
      validity: '30 days',
      dataAmount: '2GB',
    ),
    DataPlan(
      id: 'glo_3gb',
      network: NetworkProvider.glo,
      name: '3GB',
      description: 'Glo 3GB Data',
      priceNaira: 900,
      validity: '30 days',
      dataAmount: '3GB',
    ),
    DataPlan(
      id: 'glo_5gb',
      network: NetworkProvider.glo,
      name: '5GB',
      description: 'Glo 5GB Data',
      priceNaira: 1500,
      validity: '30 days',
      dataAmount: '5GB',
    ),
    DataPlan(
      id: 'glo_10gb',
      network: NetworkProvider.glo,
      name: '10GB',
      description: 'Glo 10GB Data',
      priceNaira: 3000,
      validity: '30 days',
      dataAmount: '10GB',
    ),
  ];

  static const List<DataPlan> _airtelPlans = [
    DataPlan(
      id: 'airtel_500mb',
      network: NetworkProvider.airtel,
      name: '500MB',
      description: 'Airtel 500MB Data',
      priceNaira: 150,
      validity: '30 days',
      dataAmount: '500MB',
    ),
    DataPlan(
      id: 'airtel_1gb',
      network: NetworkProvider.airtel,
      name: '1GB',
      description: 'Airtel 1GB Data',
      priceNaira: 300,
      validity: '30 days',
      dataAmount: '1GB',
    ),
    DataPlan(
      id: 'airtel_2gb',
      network: NetworkProvider.airtel,
      name: '2GB',
      description: 'Airtel 2GB Data',
      priceNaira: 600,
      validity: '30 days',
      dataAmount: '2GB',
    ),
    DataPlan(
      id: 'airtel_3gb',
      network: NetworkProvider.airtel,
      name: '3GB',
      description: 'Airtel 3GB Data',
      priceNaira: 900,
      validity: '30 days',
      dataAmount: '3GB',
    ),
    DataPlan(
      id: 'airtel_5gb',
      network: NetworkProvider.airtel,
      name: '5GB',
      description: 'Airtel 5GB Data',
      priceNaira: 1500,
      validity: '30 days',
      dataAmount: '5GB',
    ),
    DataPlan(
      id: 'airtel_10gb',
      network: NetworkProvider.airtel,
      name: '10GB',
      description: 'Airtel 10GB Data',
      priceNaira: 3000,
      validity: '30 days',
      dataAmount: '10GB',
    ),
  ];

  static const List<DataPlan> _9mobilePlans = [
    DataPlan(
      id: '9mobile_500mb',
      network: NetworkProvider.nineMobile,
      name: '500MB',
      description: '9mobile 500MB Data',
      priceNaira: 150,
      validity: '30 days',
      dataAmount: '500MB',
    ),
    DataPlan(
      id: '9mobile_1gb',
      network: NetworkProvider.nineMobile,
      name: '1GB',
      description: '9mobile 1GB Data',
      priceNaira: 300,
      validity: '30 days',
      dataAmount: '1GB',
    ),
    DataPlan(
      id: '9mobile_2gb',
      network: NetworkProvider.nineMobile,
      name: '2GB',
      description: '9mobile 2GB Data',
      priceNaira: 600,
      validity: '30 days',
      dataAmount: '2GB',
    ),
    DataPlan(
      id: '9mobile_3gb',
      network: NetworkProvider.nineMobile,
      name: '3GB',
      description: '9mobile 3GB Data',
      priceNaira: 900,
      validity: '30 days',
      dataAmount: '3GB',
    ),
    DataPlan(
      id: '9mobile_5gb',
      network: NetworkProvider.nineMobile,
      name: '5GB',
      description: '9mobile 5GB Data',
      priceNaira: 1500,
      validity: '30 days',
      dataAmount: '5GB',
    ),
    DataPlan(
      id: '9mobile_10gb',
      network: NetworkProvider.nineMobile,
      name: '10GB',
      description: '9mobile 10GB Data',
      priceNaira: 3000,
      validity: '30 days',
      dataAmount: '10GB',
    ),
  ];
}

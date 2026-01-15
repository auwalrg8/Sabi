/// International Payment Methods for P2P Trading
///
/// Supports global payment methods across different regions
library;

/// Payment method categories
enum PaymentCategory {
  bankTransfer,
  mobileMoney,
  digitalWallet,
  instantTransfer,
  giftCard,
  cash,
}

/// Regions for payment method availability
enum PaymentRegion {
  global,
  nigeria,
  africa,
  usa,
  europe,
  uk,
  india,
  brazil,
  canada,
  latinAmerica,
  asia,
}

/// International payment method definition
class InternationalPaymentMethod {
  final String id;
  final String name;
  final String shortName;
  final PaymentCategory category;
  final List<PaymentRegion> regions;
  final String? iconAsset;
  final String? colorHex;
  final bool requiresAccountDetails;
  final String? accountLabel;
  final String? accountHint;
  final List<String>? requiredFields;
  final int estimatedMinutes;
  final String? warningNote;

  const InternationalPaymentMethod({
    required this.id,
    required this.name,
    required this.shortName,
    required this.category,
    required this.regions,
    this.iconAsset,
    this.colorHex,
    this.requiresAccountDetails = true,
    this.accountLabel,
    this.accountHint,
    this.requiredFields,
    this.estimatedMinutes = 5,
    this.warningNote,
  });

  bool isAvailableIn(PaymentRegion region) {
    return regions.contains(PaymentRegion.global) || regions.contains(region);
  }
}

/// All available payment methods
class PaymentMethods {
  PaymentMethods._();

  // ============================================================================
  // NIGERIA
  // ============================================================================
  static const gtBank = InternationalPaymentMethod(
    id: 'gtbank',
    name: 'GTBank',
    shortName: 'GTBank',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#FF6600',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    requiredFields: ['accountNumber', 'accountName'],
    estimatedMinutes: 5,
  );

  static const opay = InternationalPaymentMethod(
    id: 'opay',
    name: 'OPay',
    shortName: 'OPay',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.nigeria],
    colorHex: '#00C853',
    accountLabel: 'Phone Number',
    accountHint: '080XXXXXXXX',
    estimatedMinutes: 2,
  );

  static const palmpay = InternationalPaymentMethod(
    id: 'palmpay',
    name: 'PalmPay',
    shortName: 'PalmPay',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.nigeria],
    colorHex: '#6B4EFF',
    accountLabel: 'Phone Number',
    accountHint: '080XXXXXXXX',
    estimatedMinutes: 2,
  );

  static const moniepoint = InternationalPaymentMethod(
    id: 'moniepoint',
    name: 'Moniepoint',
    shortName: 'Moniepoint',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#0066FF',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    estimatedMinutes: 3,
  );

  static const kuda = InternationalPaymentMethod(
    id: 'kuda',
    name: 'Kuda Bank',
    shortName: 'Kuda',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#40196D',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    estimatedMinutes: 3,
  );

  static const firstBank = InternationalPaymentMethod(
    id: 'firstbank',
    name: 'First Bank',
    shortName: 'FirstBank',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#003366',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    estimatedMinutes: 5,
  );

  static const accessBank = InternationalPaymentMethod(
    id: 'accessbank',
    name: 'Access Bank',
    shortName: 'Access',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#F26522',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    estimatedMinutes: 5,
  );

  static const zenithBank = InternationalPaymentMethod(
    id: 'zenithbank',
    name: 'Zenith Bank',
    shortName: 'Zenith',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.nigeria],
    colorHex: '#E31837',
    accountLabel: 'Account Number',
    accountHint: '10-digit account number',
    estimatedMinutes: 5,
  );

  // ============================================================================
  // GLOBAL / MULTI-REGION
  // ============================================================================
  static const wise = InternationalPaymentMethod(
    id: 'wise',
    name: 'Wise (TransferWise)',
    shortName: 'Wise',
    category: PaymentCategory.digitalWallet,
    regions: [PaymentRegion.global],
    colorHex: '#00B9FF',
    accountLabel: 'Email or Phone',
    accountHint: 'Your Wise email or phone',
    estimatedMinutes: 5,
  );

  static const paypal = InternationalPaymentMethod(
    id: 'paypal',
    name: 'PayPal',
    shortName: 'PayPal',
    category: PaymentCategory.digitalWallet,
    regions: [PaymentRegion.global],
    colorHex: '#003087',
    accountLabel: 'PayPal Email',
    accountHint: 'email@example.com',
    estimatedMinutes: 2,
    warningNote: 'Risk of chargebacks. Trade with trusted users only.',
  );

  static const revolut = InternationalPaymentMethod(
    id: 'revolut',
    name: 'Revolut',
    shortName: 'Revolut',
    category: PaymentCategory.digitalWallet,
    regions: [PaymentRegion.europe, PaymentRegion.uk, PaymentRegion.usa],
    colorHex: '#0075EB',
    accountLabel: 'Revolut Tag or Phone',
    accountHint: '@username or phone',
    estimatedMinutes: 2,
  );

  // ============================================================================
  // USA
  // ============================================================================
  static const venmo = InternationalPaymentMethod(
    id: 'venmo',
    name: 'Venmo',
    shortName: 'Venmo',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.usa],
    colorHex: '#008CFF',
    accountLabel: 'Venmo Username',
    accountHint: '@username',
    estimatedMinutes: 2,
    warningNote: 'Do not include notes mentioning Bitcoin or crypto.',
  );

  static const zelle = InternationalPaymentMethod(
    id: 'zelle',
    name: 'Zelle',
    shortName: 'Zelle',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.usa],
    colorHex: '#6D1ED4',
    accountLabel: 'Email or Phone',
    accountHint: 'Zelle registered email/phone',
    estimatedMinutes: 2,
  );

  static const cashApp = InternationalPaymentMethod(
    id: 'cashapp',
    name: 'Cash App',
    shortName: 'CashApp',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.usa, PaymentRegion.uk],
    colorHex: '#00D632',
    accountLabel: 'Cash Tag',
    accountHint: r'$cashtag',
    estimatedMinutes: 2,
  );

  // ============================================================================
  // EUROPE
  // ============================================================================
  static const sepa = InternationalPaymentMethod(
    id: 'sepa',
    name: 'SEPA Bank Transfer',
    shortName: 'SEPA',
    category: PaymentCategory.bankTransfer,
    regions: [PaymentRegion.europe],
    colorHex: '#003399',
    accountLabel: 'IBAN',
    accountHint: 'DE89 3704 0044 0532 0130 00',
    requiredFields: ['iban', 'bic', 'accountName'],
    estimatedMinutes: 60,
    warningNote: 'SEPA transfers may take up to 1 business day.',
  );

  static const sepaInstant = InternationalPaymentMethod(
    id: 'sepa_instant',
    name: 'SEPA Instant',
    shortName: 'SEPA Instant',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.europe],
    colorHex: '#003399',
    accountLabel: 'IBAN',
    accountHint: 'DE89 3704 0044 0532 0130 00',
    requiredFields: ['iban', 'bic', 'accountName'],
    estimatedMinutes: 2,
  );

  // ============================================================================
  // UK
  // ============================================================================
  static const fasterPayments = InternationalPaymentMethod(
    id: 'faster_payments',
    name: 'Faster Payments (UK)',
    shortName: 'Faster Pay',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.uk],
    colorHex: '#00205B',
    accountLabel: 'Sort Code & Account',
    accountHint: '12-34-56 / 12345678',
    requiredFields: ['sortCode', 'accountNumber', 'accountName'],
    estimatedMinutes: 2,
  );

  // ============================================================================
  // INDIA
  // ============================================================================
  static const upi = InternationalPaymentMethod(
    id: 'upi',
    name: 'UPI',
    shortName: 'UPI',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.india],
    colorHex: '#5F259F',
    accountLabel: 'UPI ID',
    accountHint: 'name@upi or phone@bank',
    estimatedMinutes: 1,
  );

  static const imps = InternationalPaymentMethod(
    id: 'imps',
    name: 'IMPS',
    shortName: 'IMPS',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.india],
    colorHex: '#FF6600',
    accountLabel: 'Account Number',
    accountHint: 'Bank account number',
    requiredFields: ['accountNumber', 'ifsc', 'accountName'],
    estimatedMinutes: 2,
  );

  // ============================================================================
  // BRAZIL
  // ============================================================================
  static const pix = InternationalPaymentMethod(
    id: 'pix',
    name: 'Pix',
    shortName: 'Pix',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.brazil],
    colorHex: '#32BCAD',
    accountLabel: 'Pix Key',
    accountHint: 'CPF, email, phone, or random key',
    estimatedMinutes: 1,
  );

  // ============================================================================
  // CANADA
  // ============================================================================
  static const interac = InternationalPaymentMethod(
    id: 'interac',
    name: 'Interac e-Transfer',
    shortName: 'Interac',
    category: PaymentCategory.instantTransfer,
    regions: [PaymentRegion.canada],
    colorHex: '#FFCC00',
    accountLabel: 'Email',
    accountHint: 'Interac registered email',
    estimatedMinutes: 5,
  );

  // ============================================================================
  // AFRICA (Non-Nigeria)
  // ============================================================================
  static const mpesa = InternationalPaymentMethod(
    id: 'mpesa',
    name: 'M-Pesa',
    shortName: 'M-Pesa',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.africa],
    colorHex: '#4DB848',
    accountLabel: 'Phone Number',
    accountHint: '+254XXXXXXXXX',
    estimatedMinutes: 1,
  );

  static const mtnMomo = InternationalPaymentMethod(
    id: 'mtn_momo',
    name: 'MTN Mobile Money',
    shortName: 'MTN MoMo',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.africa],
    colorHex: '#FFCC00',
    accountLabel: 'Phone Number',
    accountHint: 'MTN registered number',
    estimatedMinutes: 2,
  );

  static const airtelMoney = InternationalPaymentMethod(
    id: 'airtel_money',
    name: 'Airtel Money',
    shortName: 'Airtel',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.africa],
    colorHex: '#ED1C24',
    accountLabel: 'Phone Number',
    accountHint: 'Airtel registered number',
    estimatedMinutes: 2,
  );

  static const orangeMoney = InternationalPaymentMethod(
    id: 'orange_money',
    name: 'Orange Money',
    shortName: 'Orange',
    category: PaymentCategory.mobileMoney,
    regions: [PaymentRegion.africa],
    colorHex: '#FF6600',
    accountLabel: 'Phone Number',
    accountHint: 'Orange registered number',
    estimatedMinutes: 2,
  );

  // ============================================================================
  // GIFT CARDS
  // ============================================================================
  static const amazonGiftCard = InternationalPaymentMethod(
    id: 'amazon_gc',
    name: 'Amazon Gift Card',
    shortName: 'Amazon GC',
    category: PaymentCategory.giftCard,
    regions: [PaymentRegion.global],
    colorHex: '#FF9900',
    accountLabel: 'Gift Card Code',
    accountHint: 'XXXX-XXXXXX-XXXX',
    estimatedMinutes: 5,
    warningNote: 'Verify gift card before releasing. High scam risk.',
  );

  static const steamGiftCard = InternationalPaymentMethod(
    id: 'steam_gc',
    name: 'Steam Gift Card',
    shortName: 'Steam GC',
    category: PaymentCategory.giftCard,
    regions: [PaymentRegion.global],
    colorHex: '#1B2838',
    accountLabel: 'Gift Card Code',
    accountHint: 'XXXXX-XXXXX-XXXXX',
    estimatedMinutes: 5,
    warningNote: 'Verify gift card before releasing. High scam risk.',
  );

  // ============================================================================
  // CASH
  // ============================================================================
  static const cashInPerson = InternationalPaymentMethod(
    id: 'cash_in_person',
    name: 'Cash (In Person)',
    shortName: 'Cash',
    category: PaymentCategory.cash,
    regions: [PaymentRegion.global],
    colorHex: '#2E7D32',
    requiresAccountDetails: false,
    estimatedMinutes: 0,
    warningNote: 'Meet in safe public places. Never trade alone.',
  );

  /// All payment methods grouped by region
  static List<InternationalPaymentMethod> getAllMethods() {
    return [
      // Nigeria
      gtBank,
      opay,
      palmpay,
      moniepoint,
      kuda,
      firstBank,
      accessBank,
      zenithBank,
      // Global
      wise, paypal, revolut,
      // USA
      venmo, zelle, cashApp,
      // Europe
      sepa, sepaInstant,
      // UK
      fasterPayments,
      // India
      upi, imps,
      // Brazil
      pix,
      // Canada
      interac,
      // Africa
      mpesa, mtnMomo, airtelMoney, orangeMoney,
      // Gift Cards
      amazonGiftCard, steamGiftCard,
      // Cash
      cashInPerson,
    ];
  }

  /// Get methods available in a specific region
  static List<InternationalPaymentMethod> getMethodsForRegion(
    PaymentRegion region,
  ) {
    return getAllMethods().where((m) => m.isAvailableIn(region)).toList();
  }

  /// Get methods by category
  static List<InternationalPaymentMethod> getMethodsByCategory(
    PaymentCategory category,
  ) {
    return getAllMethods().where((m) => m.category == category).toList();
  }

  /// Find method by ID
  static InternationalPaymentMethod? getById(String id) {
    try {
      return getAllMethods().firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get popular methods (commonly used)
  static List<InternationalPaymentMethod> getPopularMethods() {
    return [
      // Nigeria favorites
      opay, palmpay, gtBank, moniepoint,
      // Global favorites
      wise, revolut,
      // US favorites
      zelle, venmo, cashApp,
      // Africa favorites
      mpesa, mtnMomo,
      // Other regions
      pix, upi, interac,
    ];
  }
}

/// User's saved payment method with their details
class UserPaymentMethod {
  final String id;
  final String methodId;
  final String label;
  final Map<String, String> details;
  final bool isDefault;
  final DateTime createdAt;

  UserPaymentMethod({
    required this.id,
    required this.methodId,
    required this.label,
    required this.details,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  InternationalPaymentMethod? get method => PaymentMethods.getById(methodId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'methodId': methodId,
    'label': label,
    'details': details,
    'isDefault': isDefault,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory UserPaymentMethod.fromJson(Map<String, dynamic> json) {
    return UserPaymentMethod(
      id: json['id'] as String,
      methodId: json['methodId'] as String,
      label: json['label'] as String,
      details: Map<String, String>.from(json['details'] as Map),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }
}

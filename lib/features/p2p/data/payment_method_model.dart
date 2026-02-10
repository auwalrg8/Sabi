import 'dart:convert';

/// Types of payment methods supported
enum PaymentMethodType { 
  bankTransfer, 
  mobileMoney, 
  cash, 
  giftCard,
  wallet,
  other,
}

/// Extension for display names
extension PaymentMethodTypeExtension on PaymentMethodType {
  String get displayName {
    switch (this) {
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.mobileMoney:
        return 'Mobile Money';
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.giftCard:
        return 'Gift Card';
      case PaymentMethodType.wallet:
        return 'Digital Wallet';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PaymentMethodType.bankTransfer:
        return '🏦';
      case PaymentMethodType.mobileMoney:
        return '📱';
      case PaymentMethodType.cash:
        return '💵';
      case PaymentMethodType.giftCard:
        return '🎁';
      case PaymentMethodType.wallet:
        return '👛';
      case PaymentMethodType.other:
        return '💳';
    }
  }
}

/// Model for a user's saved payment method
class PaymentMethodModel {
  final String id;
  final String name;
  final PaymentMethodType type;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final String? phoneNumber;
  final String? walletAddress;
  final String? instructions;
  final bool isDefault;
  final bool isSelected;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.type,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.phoneNumber,
    this.walletAddress,
    this.instructions,
    this.isDefault = false,
    this.isSelected = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Get display details based on type
  String get displayDetails {
    switch (type) {
      case PaymentMethodType.bankTransfer:
        final parts = <String>[];
        if (bankName != null && bankName!.isNotEmpty) parts.add(bankName!);
        if (accountNumber != null && accountNumber!.isNotEmpty) {
          parts.add('****${accountNumber!.substring(accountNumber!.length > 4 ? accountNumber!.length - 4 : 0)}');
        }
        return parts.join(' • ');
      case PaymentMethodType.mobileMoney:
        if (phoneNumber != null && phoneNumber!.isNotEmpty) {
          return '****${phoneNumber!.substring(phoneNumber!.length > 4 ? phoneNumber!.length - 4 : 0)}';
        }
        return bankName ?? '';
      case PaymentMethodType.cash:
        return instructions ?? 'Cash payment';
      case PaymentMethodType.giftCard:
        return instructions ?? 'Gift card';
      case PaymentMethodType.wallet:
        return walletAddress != null && walletAddress!.length > 8
            ? '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}'
            : walletAddress ?? '';
      case PaymentMethodType.other:
        return instructions ?? '';
    }
  }

  PaymentMethodModel copyWith({
    String? id,
    String? name,
    PaymentMethodType? type,
    String? bankName,
    String? accountName,
    String? accountNumber,
    String? phoneNumber,
    String? walletAddress,
    String? instructions,
    bool? isDefault,
    bool? isSelected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      walletAddress: walletAddress ?? this.walletAddress,
      instructions: instructions ?? this.instructions,
      isDefault: isDefault ?? this.isDefault,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'phoneNumber': phoneNumber,
      'walletAddress': walletAddress,
      'instructions': instructions,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PaymentMethodType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentMethodType.other,
      ),
      bankName: json['bankName'] as String?,
      accountName: json['accountName'] as String?,
      accountNumber: json['accountNumber'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      walletAddress: json['walletAddress'] as String?,
      instructions: json['instructions'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PaymentMethodModel.fromJsonString(String jsonString) {
    return PaymentMethodModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

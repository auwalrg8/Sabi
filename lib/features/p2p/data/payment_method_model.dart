enum PaymentMethodType { bankTransfer, mobileMoney, cash, giftCard }

class PaymentMethodModel {
  final String id;
  final String name;
  final PaymentMethodType type;
  final String? accountDetails;
  final bool isSelected;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.type,
    this.accountDetails,
    this.isSelected = false,
  });

  PaymentMethodModel copyWith({
    String? id,
    String? name,
    PaymentMethodType? type,
    String? accountDetails,
    bool? isSelected,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      accountDetails: accountDetails ?? this.accountDetails,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

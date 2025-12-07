import 'recipient.dart';

class SendTransaction {
  final Recipient recipient;
  final double amount;
  final String? memo;
  final double fee;
  final String? transactionId;
  final int? amountSats;
  final int? feeSats;
  final String? bolt11; // Store bolt11 invoice for later sending

  const SendTransaction({
    required this.recipient,
    required this.amount,
    this.memo,
    required this.fee,
    this.transactionId,
    this.amountSats,
    this.feeSats,
    this.bolt11,
  });

  double get total => amount + fee;
  
  double get amountInSats => amountSats != null ? amountSats!.toDouble() : amount * 1000;
  
  double get feeInSats => feeSats != null ? feeSats!.toDouble() : fee * 100;
}

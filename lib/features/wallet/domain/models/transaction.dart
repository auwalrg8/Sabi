class Transaction {
  final String id;
  final String type; // 'send', 'receive', 'buy', 'trade'
  final double amountBtc;
  final double amountNgn;
  final String? counterparty; // contact name or address
  final DateTime date;
  final String status; // 'pending', 'confirmed'
  final String? icon; // for type icon

  const Transaction({
    required this.id,
    required this.type,
    required this.amountBtc,
    required this.amountNgn,
    this.counterparty,
    required this.date,
    this.status = 'confirmed',
    this.icon,
  });
}

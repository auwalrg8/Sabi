class CashTransaction {
  final String id;
  final CashTransactionType type;
  final double amountNGN;
  final int amountSats;
  final DateTime timestamp;
  final CashTransactionStatus status;
  final String? reference;

  CashTransaction({
    required this.id,
    required this.type,
    required this.amountNGN,
    required this.amountSats,
    required this.timestamp,
    this.status = CashTransactionStatus.completed,
    this.reference,
  });

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (transactionDate == today) {
      return 'Today ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${_monthName(timestamp.month)} ${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }
}

enum CashTransactionType {
  buy,
  sell,
}

enum CashTransactionStatus {
  pending,
  processing,
  completed,
  failed,
}

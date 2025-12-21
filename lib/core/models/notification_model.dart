class NotificationItem {
  final String id;

  final String title;

  final String message;

  final double amount;

  final String currency;

  final String type; // 'payment_received', 'zap_received', 'trade_completed'

  final DateTime timestamp;

  bool isRead;

  final String? relatedTransactionId;

  final String? senderName;

  final String? senderIcon;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.amount,
    required this.currency,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.relatedTransactionId,
    this.senderName,
    this.senderIcon,
  });

  // Copy with method
  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    double? amount,
    String? currency,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? relatedTransactionId,
    String? senderName,
    String? senderIcon,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedTransactionId: relatedTransactionId ?? this.relatedTransactionId,
      senderName: senderName ?? this.senderName,
      senderIcon: senderIcon ?? this.senderIcon,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'amount': amount,
    'currency': currency,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'relatedTransactionId': relatedTransactionId,
    'senderName': senderName,
    'senderIcon': senderIcon,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
        relatedTransactionId: json['relatedTransactionId'] as String?,
        senderName: json['senderName'] as String?,
        senderIcon: json['senderIcon'] as String?,
      );
}

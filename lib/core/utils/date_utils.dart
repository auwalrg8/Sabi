// lib/core/utils/date_utils.dart

/// Formats a Unix timestamp (in milliseconds) from Breez SDK for transaction list display
/// Returns "Today at HH:MM", "Yesterday at HH:MM", or "DD/MM/YYYY HH:MM"
String formatTransactionTime(int unixTimestampMillis) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
    unixTimestampMillis,
    isUtc: true,
  );

  // Convert to local time (Nigeria is UTC+1, but .toLocal() handles any timezone)
  final DateTime localDate = date.toLocal();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final txDate = DateTime(localDate.year, localDate.month, localDate.day);

  if (txDate == today) {
    return "Today at ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";
  } else if (txDate == yesterday) {
    return "Yesterday at ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";
  } else {
    return "${localDate.day}/${localDate.month}/${localDate.year} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";
  }
}

/// Formats a Unix timestamp (in seconds) for full date display in detail screens
/// Returns "DD Mon YYYY • HH:MM" format
String formatFullDateTime(int unixTimestampMillis) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    unixTimestampMillis,
    isUtc: true,
  ).toLocal();

  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return "${date.day} ${monthNames[date.month - 1]} ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
}

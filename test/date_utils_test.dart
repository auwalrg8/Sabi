import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart';

void main() {
  group('Date Utilities Tests', () {
    test('formatTransactionTime - today', () {
      final now = DateTime.now();
      final todayMillis = now.millisecondsSinceEpoch;
      
      final result = formatTransactionTime(todayMillis);
      
      expect(result, contains('Today at'));
      expect(result, contains(':'));
    });

    test('formatTransactionTime - yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMillis = yesterday.millisecondsSinceEpoch;
      
      final result = formatTransactionTime(yesterdayMillis);
      
      expect(result, contains('Yesterday at'));
      expect(result, contains(':'));
    });

    test('formatTransactionTime - older date', () {
      final oldDate = DateTime(2025, 1, 15, 14, 30);
      final oldDateMillis = oldDate.millisecondsSinceEpoch;
      
      final result = formatTransactionTime(oldDateMillis);
      
      expect(result, contains('15/1/2025'));
      expect(result, contains(':'));
    });

    test('formatFullDateTime - correct format', () {
      final testDate = DateTime(2025, 12, 9, 14, 30);
      final testMillis = testDate.millisecondsSinceEpoch;
      
      final result = formatFullDateTime(testMillis);
      
      expect(result, contains('9 Dec 2025'));
      expect(result, contains('•'));
      expect(result, contains(':'));
    });

    test('formatFullDateTime - handles single digit time', () {
      final testDate = DateTime(2025, 1, 5, 9, 5);
      final testMillis = testDate.millisecondsSinceEpoch;
      
      final result = formatFullDateTime(testMillis);
      
      // Should pad hours and minutes with leading zeros
      expect(result, contains('09:05'));
    });

    test('Breez SDK timestamp conversion - seconds to milliseconds', () {
      // Breez SDK now gives timestamps in milliseconds directly
      const breezTimestampMillis = 1733750400000; // Dec 9, 2025 12:00:00 GMT
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        breezTimestampMillis,
        isUtc: true,
      );
      
      expect(dateTime.year, 2024);
      expect(dateTime.month, 12);
      expect(dateTime.day, 9);
    });
  });
}

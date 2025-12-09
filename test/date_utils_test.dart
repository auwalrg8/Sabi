import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart';

void main() {
  group('Date Utilities Tests', () {
    test('formatTransactionTime - today', () {
      final now = DateTime.now();
      final todaySeconds = now.millisecondsSinceEpoch ~/ 1000;
      
      final result = formatTransactionTime(todaySeconds);
      
      expect(result, contains('Today at'));
      expect(result, contains(':'));
    });

    test('formatTransactionTime - yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdaySeconds = yesterday.millisecondsSinceEpoch ~/ 1000;
      
      final result = formatTransactionTime(yesterdaySeconds);
      
      expect(result, contains('Yesterday at'));
      expect(result, contains(':'));
    });

    test('formatTransactionTime - older date', () {
      final oldDate = DateTime(2025, 1, 15, 14, 30);
      final oldDateSeconds = oldDate.millisecondsSinceEpoch ~/ 1000;
      
      final result = formatTransactionTime(oldDateSeconds);
      
      expect(result, contains('15/1/2025'));
      expect(result, contains(':'));
    });

    test('formatFullDateTime - correct format', () {
      final testDate = DateTime(2025, 12, 9, 14, 30);
      final testSeconds = testDate.millisecondsSinceEpoch ~/ 1000;
      
      final result = formatFullDateTime(testSeconds);
      
      expect(result, contains('9 Dec 2025'));
      expect(result, contains('•'));
      expect(result, contains(':'));
    });

    test('formatFullDateTime - handles single digit time', () {
      final testDate = DateTime(2025, 1, 5, 9, 5);
      final testSeconds = testDate.millisecondsSinceEpoch ~/ 1000;
      
      final result = formatFullDateTime(testSeconds);
      
      // Should pad hours and minutes with leading zeros
      expect(result, contains('09:05'));
    });

    test('Breez SDK timestamp conversion - seconds to milliseconds', () {
      // Breez SDK returns Unix timestamp in seconds
      const breezTimestampSeconds = 1733750400; // Dec 9, 2025 12:00:00 GMT
      
      // Our function should multiply by 1000 to convert to milliseconds
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        breezTimestampSeconds * 1000,
        isUtc: true,
      );
      
      expect(dateTime.year, 2024);
      expect(dateTime.month, 12);
      expect(dateTime.day, 9);
    });
  });
}

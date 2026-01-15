import 'package:flutter/foundation.dart';

/// Centralized logging service for consistent debug output across the app
class LoggerService {
  static const String _tag = '[Sabi]';

  /// Log debug messages (only in development)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag ?? _tag;
      debugPrint('$prefix [DEBUG] $message');
    }
  }

  /// Log info messages
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag ?? _tag;
      debugPrint('$prefix [INFO] $message');
    }
  }

  /// Log warning messages
  static void warn(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag ?? _tag;
      debugPrint('$prefix [WARN] $message');
    }
  }

  /// Log error messages with optional stack trace
  static void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final prefix = tag ?? _tag;
      debugPrint('$prefix [ERROR] $message');
      if (error != null) {
        debugPrint('$prefix Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('$prefix Stack trace:\n$stackTrace');
      }
    }
  }

  /// Log critical errors that should always be logged
  static void critical(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag ?? _tag;
    debugPrint('$prefix [CRITICAL] $message');
    if (error != null) {
      debugPrint('$prefix Error details: $error');
    }
    if (stackTrace != null) {
      debugPrint('$prefix Stack trace:\n$stackTrace');
    }
  }
}

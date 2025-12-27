/// P2P Logger Utility - Comprehensive error logging for serverless P2P
/// 
/// Since there's no server to track issues, we log everything locally
/// for debugging and user support.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Log levels for P2P operations
enum P2PLogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// A single log entry
class P2PLogEntry {
  final String id;
  final DateTime timestamp;
  final P2PLogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? tradeId;
  final String? errorCode;
  final String? stackTrace;

  P2PLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata,
    this.tradeId,
    this.errorCode,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'category': category,
    'message': message,
    'metadata': metadata,
    'tradeId': tradeId,
    'errorCode': errorCode,
    'stackTrace': stackTrace,
  };

  factory P2PLogEntry.fromJson(Map<String, dynamic> json) {
    return P2PLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: P2PLogLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => P2PLogLevel.info,
      ),
      category: json['category'] as String,
      message: json['message'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      tradeId: json['tradeId'] as String?,
      errorCode: json['errorCode'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  String get levelEmoji {
    switch (level) {
      case P2PLogLevel.debug:
        return '🔍';
      case P2PLogLevel.info:
        return 'ℹ️';
      case P2PLogLevel.warning:
        return '⚠️';
      case P2PLogLevel.error:
        return '❌';
      case P2PLogLevel.critical:
        return '🚨';
    }
  }

  @override
  String toString() {
    return '$levelEmoji [$category] $message${tradeId != null ? ' (Trade: $tradeId)' : ''}';
  }
}

/// P2P Error codes for common issues
class P2PErrorCodes {
  P2PErrorCodes._();

  // Trade errors
  static const tradeCreationFailed = 'P2P_TRADE_001';
  static const tradeNotFound = 'P2P_TRADE_002';
  static const tradeExpired = 'P2P_TRADE_003';
  static const tradeCancelled = 'P2P_TRADE_004';
  static const tradeAlreadyCompleted = 'P2P_TRADE_005';

  // Invoice errors
  static const invoiceCreationFailed = 'P2P_INV_001';
  static const invoiceExpired = 'P2P_INV_002';
  static const invoicePaymentFailed = 'P2P_INV_003';
  static const invoiceAmountMismatch = 'P2P_INV_004';

  // Timer errors
  static const timerExpired = 'P2P_TMR_001';
  static const timerNotStarted = 'P2P_TMR_002';

  // Verification errors
  static const codeVerificationFailed = 'P2P_VER_001';
  static const codeExpired = 'P2P_VER_002';
  static const codeMismatch = 'P2P_VER_003';

  // Network errors
  static const networkError = 'P2P_NET_001';
  static const sdkNotInitialized = 'P2P_NET_002';
  static const connectionTimeout = 'P2P_NET_003';

  // User errors
  static const insufficientBalance = 'P2P_USR_001';
  static const invalidAmount = 'P2P_USR_002';
  static const offerNotAvailable = 'P2P_USR_003';

  /// Get human-readable description for error code
  static String getDescription(String code) {
    switch (code) {
      case tradeCreationFailed:
        return 'Failed to create trade. Please try again.';
      case tradeNotFound:
        return 'Trade not found. It may have been cancelled.';
      case tradeExpired:
        return 'Trade has expired. The payment window has closed.';
      case tradeCancelled:
        return 'Trade was cancelled.';
      case tradeAlreadyCompleted:
        return 'This trade has already been completed.';
      case invoiceCreationFailed:
        return 'Failed to create Lightning invoice. Check your connection.';
      case invoiceExpired:
        return 'Invoice has expired. Start a new trade.';
      case invoicePaymentFailed:
        return 'Invoice payment failed. The seller may not have received funds.';
      case invoiceAmountMismatch:
        return 'Invoice amount does not match trade amount.';
      case timerExpired:
        return 'Payment timer has expired. Trade cancelled.';
      case timerNotStarted:
        return 'Timer has not been started yet.';
      case codeVerificationFailed:
        return 'Trade code verification failed.';
      case codeExpired:
        return 'Trade code has expired. Request a new one.';
      case codeMismatch:
        return 'Trade codes do not match. Verify with counterparty.';
      case networkError:
        return 'Network error. Check your internet connection.';
      case sdkNotInitialized:
        return 'Wallet not initialized. Please restart the app.';
      case connectionTimeout:
        return 'Connection timed out. Please try again.';
      case insufficientBalance:
        return 'Insufficient balance for this trade.';
      case invalidAmount:
        return 'Invalid amount. Check min/max limits.';
      case offerNotAvailable:
        return 'This offer is no longer available.';
      default:
        return 'An unknown error occurred.';
    }
  }

  /// Get suggested action for error code
  static String getSuggestedAction(String code) {
    switch (code) {
      case tradeCreationFailed:
      case invoiceCreationFailed:
      case networkError:
      case connectionTimeout:
        return 'Check your internet connection and try again.';
      case tradeExpired:
      case invoiceExpired:
      case timerExpired:
        return 'Start a new trade with the same offer.';
      case codeVerificationFailed:
      case codeMismatch:
        return 'Contact the other party to verify the correct code.';
      case insufficientBalance:
        return 'Add more funds to your wallet before creating offers.';
      case sdkNotInitialized:
        return 'Close and reopen the app, then try again.';
      default:
        return 'Try again or contact support if the issue persists.';
    }
  }
}

/// Main P2P Logger class
class P2PLogger {
  P2PLogger._();

  static const _prefsKey = 'p2p_logs';
  static const _maxLogs = 500;
  static final List<P2PLogEntry> _memoryLogs = [];
  static bool _initialized = false;

  /// Initialize the logger and load persisted logs
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _memoryLogs.addAll(
          list.map((e) => P2PLogEntry.fromJson(Map<String, dynamic>.from(e as Map))),
        );
      }
      _initialized = true;
      info('Logger', 'P2P Logger initialized with ${_memoryLogs.length} logs');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize P2P Logger: $e');
    }
  }

  /// Save logs to persistent storage
  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_memoryLogs.map((l) => l.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      debugPrint('⚠️ Failed to persist P2P logs: $e');
    }
  }

  /// Add a log entry
  static void _log(
    P2PLogLevel level,
    String category,
    String message, {
    Map<String, dynamic>? metadata,
    String? tradeId,
    String? errorCode,
    StackTrace? stackTrace,
  }) {
    final entry = P2PLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata,
      tradeId: tradeId,
      errorCode: errorCode,
      stackTrace: stackTrace?.toString(),
    );

    _memoryLogs.add(entry);

    // Trim old logs
    while (_memoryLogs.length > _maxLogs) {
      _memoryLogs.removeAt(0);
    }

    // Print to debug console
    debugPrint(entry.toString());

    // Persist async
    _persist();
  }

  /// Log debug message
  static void debug(String category, String message, {Map<String, dynamic>? metadata, String? tradeId}) {
    _log(P2PLogLevel.debug, category, message, metadata: metadata, tradeId: tradeId);
  }

  /// Log info message
  static void info(String category, String message, {Map<String, dynamic>? metadata, String? tradeId}) {
    _log(P2PLogLevel.info, category, message, metadata: metadata, tradeId: tradeId);
  }

  /// Log warning message
  static void warning(String category, String message, {Map<String, dynamic>? metadata, String? tradeId}) {
    _log(P2PLogLevel.warning, category, message, metadata: metadata, tradeId: tradeId);
  }

  /// Log error message
  static void error(
    String category,
    String message, {
    Map<String, dynamic>? metadata,
    String? tradeId,
    String? errorCode,
    StackTrace? stackTrace,
  }) {
    _log(
      P2PLogLevel.error,
      category,
      message,
      metadata: metadata,
      tradeId: tradeId,
      errorCode: errorCode,
      stackTrace: stackTrace,
    );
  }

  /// Log critical error
  static void critical(
    String category,
    String message, {
    Map<String, dynamic>? metadata,
    String? tradeId,
    String? errorCode,
    StackTrace? stackTrace,
  }) {
    _log(
      P2PLogLevel.critical,
      category,
      message,
      metadata: metadata,
      tradeId: tradeId,
      errorCode: errorCode,
      stackTrace: stackTrace,
    );
  }

  /// Get all logs
  static List<P2PLogEntry> getAllLogs() => List.unmodifiable(_memoryLogs);

  /// Get logs for a specific trade
  static List<P2PLogEntry> getLogsForTrade(String tradeId) {
    return _memoryLogs.where((l) => l.tradeId == tradeId).toList();
  }

  /// Get logs by level
  static List<P2PLogEntry> getLogsByLevel(P2PLogLevel level) {
    return _memoryLogs.where((l) => l.level == level).toList();
  }

  /// Get recent logs
  static List<P2PLogEntry> getRecentLogs({int count = 50}) {
    final start = _memoryLogs.length > count ? _memoryLogs.length - count : 0;
    return _memoryLogs.sublist(start);
  }

  /// Get error logs only
  static List<P2PLogEntry> getErrors() {
    return _memoryLogs.where((l) => 
      l.level == P2PLogLevel.error || l.level == P2PLogLevel.critical
    ).toList();
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    _memoryLogs.clear();
    await _persist();
  }

  /// Export logs as JSON string (for support)
  static String exportLogs() {
    return const JsonEncoder.withIndent('  ').convert(
      _memoryLogs.map((l) => l.toJson()).toList(),
    );
  }

  /// Export logs for a specific trade (for support)
  static String exportTradeLog(String tradeId) {
    final tradeLogs = getLogsForTrade(tradeId);
    return const JsonEncoder.withIndent('  ').convert(
      tradeLogs.map((l) => l.toJson()).toList(),
    );
  }
}

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Debug log entry for Nostr operations
class NostrDebugEntry {
  final DateTime timestamp;
  final String level; // INFO, WARN, ERROR, SUCCESS
  final String category; // INIT, RELAY, FEED, KEYS, DM
  final String message;
  final String? details;

  NostrDebugEntry({
    required this.level,
    required this.category,
    required this.message,
    this.details,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final icon = switch (level) {
      'SUCCESS' => '✅',
      'WARN' => '⚠️',
      'ERROR' => '❌',
      _ => 'ℹ️',
    };
    return '$time $icon [$category] $message${details != null ? '\n   └─ $details' : ''}';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'category': category,
    'message': message,
    'details': details,
  };
}

/// Singleton service for collecting Nostr debug logs
class NostrDebugService {
  static final NostrDebugService _instance = NostrDebugService._();
  factory NostrDebugService() => _instance;
  NostrDebugService._();

  // Keep last 500 log entries
  final _logs = Queue<NostrDebugEntry>();
  static const _maxLogs = 500;

  // Connection status tracking
  final Map<String, bool> _relayStatus = {};
  bool _isInitialized = false;
  bool _hasKeys = false;
  String? _currentNpub;
  int _connectedRelays = 0;
  int _totalRelays = 0;

  // Stream for live updates
  final _logController = StreamController<NostrDebugEntry>.broadcast();
  Stream<NostrDebugEntry> get logStream => _logController.stream;

  /// Log an entry
  void log(String level, String category, String message, [String? details]) {
    final entry = NostrDebugEntry(
      level: level,
      category: category,
      message: message,
      details: details,
    );

    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // Also print to console
    debugPrint(entry.toString());

    // Notify listeners
    _logController.add(entry);
  }

  // Convenience methods
  void info(String category, String message, [String? details]) =>
      log('INFO', category, message, details);

  void success(String category, String message, [String? details]) =>
      log('SUCCESS', category, message, details);

  void warn(String category, String message, [String? details]) =>
      log('WARN', category, message, details);

  void error(String category, String message, [String? details]) =>
      log('ERROR', category, message, details);

  /// Update relay status
  void updateRelayStatus(String relayUrl, bool connected) {
    _relayStatus[relayUrl] = connected;
    _connectedRelays = _relayStatus.values.where((v) => v).length;
    _totalRelays = _relayStatus.length;
  }

  /// Update initialization status
  void updateInitStatus({bool? initialized, bool? hasKeys, String? npub}) {
    if (initialized != null) _isInitialized = initialized;
    if (hasKeys != null) _hasKeys = hasKeys;
    if (npub != null) _currentNpub = npub;
  }

  /// Get all logs
  List<NostrDebugEntry> get logs => _logs.toList();

  /// Get logs as formatted string
  String getLogsAsString() {
    return _logs.map((e) => e.toString()).join('\n');
  }

  /// Get connection summary
  Map<String, dynamic> getConnectionSummary() => {
    'isInitialized': _isInitialized,
    'hasKeys': _hasKeys,
    'currentNpub': _currentNpub,
    'connectedRelays': _connectedRelays,
    'totalRelays': _totalRelays,
    'relayStatus': Map.from(_relayStatus),
  };

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  void dispose() {
    _logController.close();
  }
}

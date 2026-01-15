import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'models/models.dart';

/// Relay connection status
enum RelayStatus { connecting, connected, disconnected, error }

/// Individual relay connection with health monitoring
class RelayConnection {
  final String url;
  WebSocket? _socket;
  RelayStatus _status = RelayStatus.disconnected;
  DateTime? _lastConnected;
  DateTime? _lastMessageReceived;
  int _reconnectAttempts = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  final List<int> _latencyMs = [];
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  // Subscription management
  final Map<String, Function(NostrEvent)> _subscriptions = {};
  final StreamController<NostrEvent> _eventController =
      StreamController.broadcast();

  RelayConnection(this.url);

  RelayStatus get status => _status;
  bool get isConnected => _status == RelayStatus.connected && _socket != null;
  Stream<NostrEvent> get eventStream => _eventController.stream;
  DateTime? get lastConnected => _lastConnected;
  DateTime? get lastMessageReceived => _lastMessageReceived;

  /// Average latency in milliseconds
  double get avgLatencyMs {
    if (_latencyMs.isEmpty) return 999;
    return _latencyMs.reduce((a, b) => a + b) / _latencyMs.length;
  }

  /// Success rate (0-100)
  double get successRate {
    final total = _successfulRequests + _failedRequests;
    if (total == 0) return 100;
    return (_successfulRequests / total) * 100;
  }

  /// Health score (0-100) based on latency and success rate
  double get healthScore {
    final latencyScore = (1000 - avgLatencyMs.clamp(0, 1000)) / 10; // 0-100
    return (latencyScore + successRate) / 2;
  }

  /// Connect to the relay
  Future<bool> connect() async {
    if (isConnected) return true;

    _status = RelayStatus.connecting;
    final startTime = DateTime.now();

    try {
      _socket = await WebSocket.connect(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      _status = RelayStatus.connected;
      _lastConnected = DateTime.now();
      _reconnectAttempts = 0;

      // Record connection latency
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      _recordLatency(latency);

      debugPrint('✅ Connected to $url (${latency}ms)');

      // Listen for messages
      _socket!.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('❌ Relay error ($url): $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('🔌 Relay disconnected: $url');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      // Start ping timer to keep connection alive
      _startPingTimer();

      return true;
    } catch (e) {
      _status = RelayStatus.error;
      _failedRequests++;
      debugPrint('❌ Failed to connect to $url: $e');
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from the relay
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscriptions.clear();

    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
    _status = RelayStatus.disconnected;
  }

  /// Send a REQ message to subscribe to events
  String subscribe(Map<String, dynamic> filter, Function(NostrEvent) onEvent) {
    final subId =
        'sub_${DateTime.now().millisecondsSinceEpoch}_${_subscriptions.length}';
    _subscriptions[subId] = onEvent;

    if (isConnected) {
      final req = jsonEncode(['REQ', subId, filter]);
      _socket!.add(req);
    }

    return subId;
  }

  /// Unsubscribe from a subscription
  void unsubscribe(String subId) {
    _subscriptions.remove(subId);

    if (isConnected) {
      final close = jsonEncode(['CLOSE', subId]);
      _socket!.add(close);
    }
  }

  /// Publish an event
  Future<bool> publish(Map<String, dynamic> event) async {
    if (!isConnected) return false;

    try {
      final eventMsg = jsonEncode(['EVENT', event]);
      _socket!.add(eventMsg);
      _successfulRequests++;
      return true;
    } catch (e) {
      _failedRequests++;
      debugPrint('❌ Failed to publish to $url: $e');
      return false;
    }
  }

  void _handleMessage(dynamic data) {
    _lastMessageReceived = DateTime.now();

    try {
      final message = jsonDecode(data as String) as List<dynamic>;
      if (message.isEmpty) return;

      final messageType = message[0] as String;

      switch (messageType) {
        case 'EVENT':
          if (message.length >= 3) {
            final subId = message[1] as String;
            final eventData = message[2] as Map<String, dynamic>;
            final event = NostrEvent.fromJson(eventData, relay: url);

            // Notify specific subscription
            if (_subscriptions.containsKey(subId)) {
              _subscriptions[subId]!(event);
            }

            // Broadcast to stream
            _eventController.add(event);
            _successfulRequests++;
          }
          break;

        case 'EOSE':
          // End of stored events - subscription caught up
          break;

        case 'OK':
          // Event published successfully
          _successfulRequests++;
          break;

        case 'NOTICE':
          debugPrint(
            '📢 Relay notice ($url): ${message.length > 1 ? message[1] : ""}',
          );
          break;

        case 'AUTH':
          // NIP-42 authentication required - not implemented yet
          debugPrint('🔐 Auth required for $url (not implemented)');
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse message from $url: $e');
    }
  }

  void _handleDisconnect() {
    _status = RelayStatus.disconnected;
    _socket = null;
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    final delay = Duration(
      seconds: (1 << _reconnectAttempts.clamp(0, 5)).clamp(1, 30),
    );

    debugPrint(
      '⏰ Scheduling reconnect to $url in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (_status != RelayStatus.connected) {
        connect();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        // Send a simple REQ that will get EOSE quickly to keep connection alive
        final pingFilter = {
          'kinds': [0],
          'limit': 1,
          'since': 9999999999,
        };
        final pingId = 'ping_${DateTime.now().millisecondsSinceEpoch}';
        _socket!.add(jsonEncode(['REQ', pingId, pingFilter]));

        // Close immediately
        Future.delayed(const Duration(milliseconds: 100), () {
          if (isConnected) {
            _socket!.add(jsonEncode(['CLOSE', pingId]));
          }
        });
      }
    });
  }

  void _recordLatency(int ms) {
    _latencyMs.add(ms);
    if (_latencyMs.length > 10) {
      _latencyMs.removeAt(0);
    }
  }

  @override
  String toString() =>
      'RelayConnection($url, status: $_status, health: ${healthScore.toStringAsFixed(1)})';
}

/// High-performance relay pool manager with comprehensive relay list
class RelayPoolManager {
  static final RelayPoolManager _instance = RelayPoolManager._internal();
  factory RelayPoolManager() => _instance;
  RelayPoolManager._internal();

  /// Comprehensive relay list (55+ relays) for maximum DM coverage
  /// Organized by tier for intelligent connection management
  /// Curated list of reliable, high-performance relays
  /// Reduced from 55+ to 20 to avoid rate limiting
  static const List<String> primalRelays = [
    // ========== TIER 1: Core High-Performance Relays ==========
    'wss://relay.primal.net', // Primal's main relay - excellent uptime
    'wss://relay.damus.io', // Damus relay - very popular
    'wss://relay.snort.social', // Snort relay - high performance
    'wss://nos.lol', // Fast and reliable
    'wss://nostr.wine', // Premium relay
    'wss://relay.nostr.band', // Good for discovery
    'wss://purplepag.es', // NIP-65 discovery relay
    // ========== TIER 2: Popular Relays ==========
    'wss://nostr.oxtr.dev', // Reliable community relay
    'wss://eden.nostr.land', // Good performance
    'wss://nostr.bitcoiner.social', // Bitcoin-focused
    'wss://offchain.pub', // Reliable
    'wss://nostr.fmt.wiz.biz', // Long-running relay
    // ========== TIER 3: DM & Inbox Relays ==========
    'wss://inbox.nostr.wine', // DM-focused (requires NIP-42 for some)
    'wss://nostr.land', // Good for DMs
    'wss://nostr-pub.wellorder.net', // Reliable fallback
    // ========== TIER 4: Regional Diversity ==========
    'wss://relay.nostr.ch', // Europe
    'wss://nostr.swiss', // Europe
    'wss://relay.nostr.wirednet.jp', // Asia
    'wss://nostr.einundzwanzig.space', // German community
  ];

  final Map<String, RelayConnection> _relays = {};
  final StreamController<NostrEvent> _globalEventController =
      StreamController.broadcast();
  bool _initialized = false;
  Timer? _healthCheckTimer;

  bool get isInitialized => _initialized;
  Stream<NostrEvent> get eventStream => _globalEventController.stream;

  /// Get the count of connected relays
  int get connectedCount => _relays.values.where((r) => r.isConnected).length;

  /// Get all connected relays sorted by health
  List<RelayConnection> get connectedRelays {
    return _relays.values.where((r) => r.isConnected).toList()
      ..sort((a, b) => b.healthScore.compareTo(a.healthScore));
  }

  /// Get relay status summary
  Map<String, dynamic> get statusSummary {
    final connected = _relays.values.where((r) => r.isConnected).length;
    final total = _relays.length;
    final avgHealth =
        _relays.values.isEmpty
            ? 0.0
            : _relays.values.map((r) => r.healthScore).reduce((a, b) => a + b) /
                _relays.length;

    return {
      'connected': connected,
      'total': total,
      'avgHealth': avgHealth,
      'relays': _relays.map(
        (url, relay) => MapEntry(url, {
          'status': relay.status.name,
          'health': relay.healthScore,
          'latency': relay.avgLatencyMs,
        }),
      ),
    };
  }

  /// Initialize the relay pool and connect to all relays
  Future<void> init({List<String>? customRelays}) async {
    if (_initialized) return;

    final relays = customRelays ?? primalRelays;
    debugPrint('🔌 Initializing relay pool with ${relays.length} relays...');

    // Create relay connections
    for (final url in relays) {
      _relays[url] = RelayConnection(url);
    }

    // Connect to all relays in parallel
    await Future.wait(
      _relays.values.map((relay) async {
        await relay.connect();
        // Forward events to global stream
        relay.eventStream.listen((event) {
          _globalEventController.add(event);
        });
      }),
    );

    // Start health check timer
    _startHealthCheckTimer();

    _initialized = true;
    debugPrint(
      '✅ Relay pool initialized. ${connectedRelays.length}/${_relays.length} connected.',
    );
  }

  /// Reconnect to all relays
  Future<void> reconnect() async {
    debugPrint('🔄 Reconnecting all relays...');
    await Future.wait(_relays.values.map((r) => r.connect()));
  }

  /// Subscribe to events across all connected relays
  /// Returns a map of subId -> relay URL
  Map<String, String> subscribe(
    Map<String, dynamic> filter,
    Function(NostrEvent) onEvent, {
    int maxRelays = 5,
  }) {
    final results = <String, String>{};
    final relays = connectedRelays.take(maxRelays);

    for (final relay in relays) {
      final subId = relay.subscribe(filter, onEvent);
      results[subId] = relay.url;
    }

    return results;
  }

  /// Unsubscribe from all relays
  void unsubscribeAll(Map<String, String> subscriptions) {
    for (final entry in subscriptions.entries) {
      final relay = _relays[entry.value];
      relay?.unsubscribe(entry.key);
    }
  }

  /// Publish an event to all connected relays
  Future<int> publish(Map<String, dynamic> event) async {
    int successCount = 0;

    await Future.wait(
      connectedRelays.map((relay) async {
        if (await relay.publish(event)) {
          successCount++;
        }
      }),
    );

    debugPrint(
      '📤 Published event to $successCount/${connectedRelays.length} relays',
    );
    return successCount;
  }

  /// Fetch events with a filter (one-shot query) - OPTIMIZED for speed
  /// Queries relays with early completion when we have enough events
  Future<List<NostrEvent>> fetch({
    required Map<String, dynamic> filter,
    int timeoutSeconds = 8,
    int maxEvents = 50,
    int maxRelays = 50,
    bool earlyComplete = true, // Complete early when we have enough events
  }) async {
    final events = <String, NostrEvent>{};
    final completer = Completer<List<NostrEvent>>();
    final subscriptions = <String, String>{};
    int relaysResponded = 0;

    // Subscribe to connected relays (up to maxRelays)
    final relays = connectedRelays.take(maxRelays).toList();
    final targetRelays = relays.length;

    if (targetRelays == 0) {
      debugPrint('⚠️ No connected relays for fetch');
      return [];
    }

    debugPrint('📨 Fetching from $targetRelays relays...');

    // Set up timeout
    final timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        debugPrint(
          '📨 Fetch timeout: ${events.length} events from $relaysResponded/$targetRelays relays',
        );
        completer.complete(events.values.toList());
      }
    });

    // Early completion check - complete when:
    // 1. We have enough events, OR
    // 2. Most relays have responded
    void checkEarlyComplete() {
      if (completer.isCompleted || !earlyComplete) return;

      // Complete early if we have enough events
      if (events.length >= maxEvents) {
        debugPrint('📨 Early complete: got $maxEvents events');
        timeoutTimer.cancel();
        completer.complete(events.values.toList());
        return;
      }

      // Complete early if 60% of relays responded (don't wait for slow ones)
      if (relaysResponded >= (targetRelays * 0.6).ceil()) {
        debugPrint(
          '📨 Early complete: $relaysResponded/$targetRelays relays, ${events.length} events',
        );
        timeoutTimer.cancel();
        completer.complete(events.values.toList());
      }
    }

    for (final relay in relays) {
      final subId = relay.subscribe(filter, (event) {
        if (!events.containsKey(event.id) && !completer.isCompleted) {
          events[event.id] = event;
          checkEarlyComplete();
        }
      });
      subscriptions[subId] = relay.url;

      // Track relay responses via EOSE (end of stored events)
      // Use a small delay to count as "responded" since we can't hook EOSE directly
      Future.delayed(const Duration(milliseconds: 500), () {
        relaysResponded++;
        checkEarlyComplete();
      });
    }

    // Wait for completion
    final result = await completer.future;

    // Clean up subscriptions
    unsubscribeAll(subscriptions);

    return result;
  }

  /// Disconnect from all relays
  Future<void> disconnect() async {
    _healthCheckTimer?.cancel();
    await Future.wait(_relays.values.map((r) => r.disconnect()));
    _initialized = false;
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Reconnect any disconnected relays
      for (final relay in _relays.values) {
        if (!relay.isConnected) {
          relay.connect();
        }
      }
    });
  }

  /// Get relay by URL
  RelayConnection? getRelay(String url) => _relays[url];

  /// Add a custom relay
  Future<void> addRelay(String url) async {
    if (_relays.containsKey(url)) return;

    final relay = RelayConnection(url);
    _relays[url] = relay;
    await relay.connect();

    relay.eventStream.listen((event) {
      _globalEventController.add(event);
    });
  }

  /// Remove a relay
  Future<void> removeRelay(String url) async {
    final relay = _relays.remove(url);
    await relay?.disconnect();
  }
}

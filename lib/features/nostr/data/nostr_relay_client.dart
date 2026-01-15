import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sabi_wallet/features/nostr/services/nostr_debug_service.dart';

/// Direct WebSocket client for Nostr relays
/// Bypasses nostr_dart library for more reliable event fetching
class NostrRelayClient {
  static final _debug = NostrDebugService();

  /// Fetch events directly from relays using raw WebSocket connections
  /// This bypasses nostr_dart which has issues receiving events on Windows
  static Future<List<Map<String, dynamic>>> fetchEvents({
    required List<String> relayUrls,
    required Map<String, dynamic> filter,
    int timeoutSeconds = 10,
    int maxEvents = 50,
  }) async {
    final events = <String, Map<String, dynamic>>{};
    final completer = Completer<List<Map<String, dynamic>>>();
    final activeConnections = <WebSocket>[];

    _debug.info(
      'DIRECT',
      'Starting direct WebSocket fetch',
      '${relayUrls.length} relays',
    );

    // Set up timeout
    final timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        _debug.info(
          'DIRECT',
          'Timeout reached',
          '${events.length} events collected',
        );
        // Close all connections
        for (final ws in activeConnections) {
          try {
            ws.close();
          } catch (_) {}
        }
        completer.complete(events.values.toList());
      }
    });

    // Connect to relays in parallel
    final subscriptionId = 'direct_${DateTime.now().millisecondsSinceEpoch}';
    final reqMessage = jsonEncode(['REQ', subscriptionId, filter]);

    _debug.info('DIRECT', 'REQ message', reqMessage);

    int connectedCount = 0;

    for (final relayUrl in relayUrls) {
      // Don't await - connect to all relays in parallel
      _connectAndFetch(
        relayUrl: relayUrl,
        reqMessage: reqMessage,
        subscriptionId: subscriptionId,
        events: events,
        activeConnections: activeConnections,
        maxEvents: maxEvents,
        completer: completer,
        timeoutTimer: timeoutTimer,
        onConnect: () {
          connectedCount++;
          _debug.success(
            'DIRECT',
            'Connected to $relayUrl',
            '$connectedCount relays',
          );
        },
      );
    }

    return completer.future;
  }

  static Future<void> _connectAndFetch({
    required String relayUrl,
    required String reqMessage,
    required String subscriptionId,
    required Map<String, Map<String, dynamic>> events,
    required List<WebSocket> activeConnections,
    required int maxEvents,
    required Completer<List<Map<String, dynamic>>> completer,
    required Timer timeoutTimer,
    required VoidCallback onConnect,
  }) async {
    try {
      // Connect with timeout
      final ws = await WebSocket.connect(relayUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      activeConnections.add(ws);
      onConnect();

      // Send REQ
      ws.add(reqMessage);
      _debug.info('DIRECT', 'REQ sent to $relayUrl');

      // Listen for events
      ws.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as List<dynamic>;
            final messageType = message[0] as String;

            if (messageType == 'EVENT' && message.length >= 3) {
              final eventData = message[2] as Map<String, dynamic>;
              final eventId = eventData['id'] as String;

              if (!events.containsKey(eventId)) {
                events[eventId] = eventData;
                _debug.success(
                  'DIRECT',
                  'EVENT from $relayUrl',
                  'id: ${eventId.substring(0, 8)}... (total: ${events.length})',
                );

                // Check if we have enough events
                if (events.length >= maxEvents && !completer.isCompleted) {
                  _debug.success(
                    'DIRECT',
                    'Max events reached',
                    '${events.length} events',
                  );
                  timeoutTimer.cancel();
                  for (final conn in activeConnections) {
                    try {
                      conn.close();
                    } catch (_) {}
                  }
                  completer.complete(events.values.toList());
                }
              }
            } else if (messageType == 'EOSE') {
              _debug.info(
                'DIRECT',
                'EOSE from $relayUrl',
                'End of stored events',
              );
            } else if (messageType == 'NOTICE') {
              _debug.warn(
                'DIRECT',
                'NOTICE from $relayUrl',
                message.length > 1 ? message[1].toString() : '',
              );
            }
          } catch (e) {
            _debug.warn('DIRECT', 'Parse error from $relayUrl', e.toString());
          }
        },
        onError: (error) {
          _debug.warn('DIRECT', 'Error from $relayUrl', error.toString());
        },
        onDone: () {
          _debug.info('DIRECT', 'Connection closed', relayUrl);
        },
      );
    } catch (e) {
      _debug.warn('DIRECT', 'Failed to connect to $relayUrl', e.toString());
    }
  }

  /// Publish an event to a relay
  static Future<bool> publishEvent({
    required String relayUrl,
    required Map<String, dynamic> event,
  }) async {
    try {
      _debug.info(
        'PUBLISH',
        'Publishing to $relayUrl',
        'kind: ${event['kind']}',
      );

      final ws = await WebSocket.connect(relayUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      // Send EVENT message
      final eventMessage = jsonEncode(['EVENT', event]);
      ws.add(eventMessage);
      _debug.info('PUBLISH', 'EVENT sent to $relayUrl');

      // Wait briefly for OK response
      bool success = false;
      await for (final data in ws.timeout(const Duration(seconds: 3))) {
        try {
          final message = jsonDecode(data as String) as List<dynamic>;
          final messageType = message[0] as String;

          if (messageType == 'OK' && message.length >= 3) {
            success = message[2] as bool;
            _debug.info('PUBLISH', 'OK from $relayUrl', 'success: $success');
            break;
          } else if (messageType == 'NOTICE') {
            _debug.warn(
              'PUBLISH',
              'NOTICE from $relayUrl',
              message[1].toString(),
            );
          }
        } catch (e) {
          // Ignore parse errors
        }
      }

      ws.close();
      return success;
    } catch (e) {
      _debug.warn('PUBLISH', 'Failed to publish to $relayUrl', e.toString());
      return false;
    }
  }
}

typedef VoidCallback = void Function();

import 'package:nostr_dart/nostr_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

class NostrService {
  // Custom kind for P2P offers
  static const int p2pOfferKind = 38383;
  static const _boxName = 'nostr_keys';
  static late Box _box;
  static Nostr? _nostr;
  static bool _initialized = false;

  /// Check if Nostr is properly initialized with keys and relays
  static bool get isInitialized => _initialized && _nostr != null;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    await _initNostr();
  }

  /// Ensure Nostr is initialized before use. Call this before any Nostr operations.
  static Future<bool> ensureInitialized() async {
    if (_nostr != null) return true;
    try {
      await _initNostr();
      return _nostr != null;
    } catch (e) {
      debugPrint('NostrService: Failed to initialize: $e');
      return false;
    }
  }

  static Future<void> _initNostr() async {
    final nsec = _box.get('nsec');
    if (nsec != null) {
      _nostr = Nostr(privateKey: nsec);
      // Add relays
      for (final relay in _defaultRelays) {
        try {
          await _nostr!.pool.add(Relay(relay, access: WriteAccess.readWrite));
        } catch (e) {
          debugPrint('NostrService: Failed to add relay $relay: $e');
        }
      }
      _initialized = true;
      debugPrint(
        'NostrService: Initialized with ${_defaultRelays.length} relays',
      );
    }
  }

  static Future<void> generateKeys() async {
    final nsec = generatePrivateKey();
    final npub = getPublicKey(nsec);
    await _box.put('nsec', nsec);
    await _box.put('npub', npub);
    await _initNostr();
  }

  static Future<void> importKeys({
    required String nsec,
    required String npub,
  }) async {
    await _box.put('nsec', nsec);
    await _box.put('npub', npub);
    await _initNostr();
  }

  static String? get npub => _box.get('npub');
  static String? get nsec => _box.get('nsec');

  static List<String> get _defaultRelays => [
    'wss://relay.damus.io',
    'wss://nostr.btclibrary.org',
    'wss://nos.lol',
    'wss://nostr.oxtr.dev',
    'wss://relay.nostr.band',
    'wss://relay.primal.net',
    'wss://relay.nostr.info',
    'wss://nostr.wine',
  ];

  static Future<Map<String, dynamic>?> getProfile() async {
    if (_nostr == null) return null;
    // NIP-01: Fetch metadata event for this pubkey
    final filter = {
      'kinds': [0],
      'authors': [npub!],
    };
    List<Event> events = [];
    _nostr!.pool.subscribe([filter], (event) => events.add(event), 'profile');
    // Wait briefly for events to arrive (in real code, use a better sync)
    await Future.delayed(const Duration(seconds: 2));
    _nostr!.pool.unsubscribe('profile');
    if (events.isNotEmpty) {
      final content = events.first.content;
      try {
        return Map<String, dynamic>.from(jsonDecode(content));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> sendZap({
    required String toNpub,
    required int amount,
    String? note,
  }) async {
    if (_nostr == null) throw Exception('Nostr not initialized');
    // NIP-57: Zap event (simplified, real implementation may require LNURL, invoice, etc.)
    final event = Event(
      npub!,
      9734, // kind for zap
      [],
      note ?? 'Zap $amount sats',
    );
    _nostr!.sendEvent(event);
  }

  static Stream<Event> listenForZaps() {
    if (_nostr == null) throw Exception('Nostr not initialized');
    final filter = {
      'kinds': [9734],
      'authors': [npub!],
    };
    // Listen for zap events to this pubkey
    final controller = StreamController<Event>();
    _nostr!.pool.subscribe([filter], (event) => controller.add(event), 'zaps');
    return controller.stream;
  }

  /// Publish a P2P offer as a Nostr event (kind `p2pOfferKind`).
  /// `offer` should be a JSON-serializable map matching `P2POfferModel.toJson()`.
  static Future<void> publishOffer(Map<String, dynamic> offer) async {
    if (_nostr == null) {
      final ok = await ensureInitialized();
      if (!ok) throw Exception('Nostr not initialized');
    }
    final content = jsonEncode(offer);
    final event = Event(npub!, p2pOfferKind, [], content);
    _nostr!.sendEvent(event);
    debugPrint('NostrService: Published offer ${offer['id']}');
  }

  /// Publish an offer cancel event. Consumers should provide the `id` of the offer to cancel.
  static Future<void> publishOfferCancel(String id) async {
    if (_nostr == null) {
      final ok = await ensureInitialized();
      if (!ok) throw Exception('Nostr not initialized');
    }
    final payload = jsonEncode({'id': id, 'action': 'cancel'});
    final event = Event(npub!, p2pOfferKind, [], payload);
    _nostr!.sendEvent(event);
    debugPrint('NostrService: Published offer cancel for $id');
  }

  /// Publish an offer update event. `offer` map should contain updated fields and the `id`.
  static Future<void> publishOfferUpdate(Map<String, dynamic> offer) async {
    if (_nostr == null) {
      final ok = await ensureInitialized();
      if (!ok) throw Exception('Nostr not initialized');
    }
    final payload = jsonEncode({...offer, 'action': 'update'});
    final event = Event(npub!, p2pOfferKind, [], payload);
    _nostr!.sendEvent(event);
    debugPrint('NostrService: Published offer update for ${offer['id']}');
  }

  /// Fetch P2P offers from relays (one-shot query).
  /// Returns a list of parsed offer events. Waits for relay responses.
  static Future<List<Map<String, dynamic>>> fetchOffers({
    int limit = 100,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_nostr == null) {
      final ok = await ensureInitialized();
      if (!ok) return [];
    }

    final filter = {
      'kinds': [p2pOfferKind],
      'limit': limit,
    };

    final offers = <String, Map<String, dynamic>>{};

    _nostr!.pool.subscribe([filter], (event) {
      try {
        final content = event.content;
        final map = jsonDecode(content) as Map<String, dynamic>;
        final action = map['action'] as String?;

        if (action == 'cancel') {
          final id = map['id'] as String? ?? event.id;
          offers.remove(id);
        } else {
          final id = map['id'] as String? ?? event.id;
          map['id'] = id;
          offers[id] = map;
        }
      } catch (e) {
        debugPrint('NostrService: Failed to parse offer event: $e');
      }
    }, 'p2p_offers_fetch');

    // Wait for events to arrive
    await Future.delayed(timeout);
    _nostr!.pool.unsubscribe('p2p_offers_fetch');

    debugPrint('NostrService: Fetched ${offers.length} offers from relays');
    return offers.values.toList();
  }

  /// Subscribe to P2P offer events (kind `p2pOfferKind`).
  /// Returns a stream of incoming `Event` objects. Consumers should parse `event.content` as JSON.
  static Stream<Event> subscribeToOffers({int limit = 100}) {
    if (_nostr == null) throw Exception('Nostr not initialized');
    final filter = {
      'kinds': [p2pOfferKind],
      'limit': limit,
    };

    final controller = StreamController<Event>();
    _nostr!.pool.subscribe(
      [filter],
      (event) => controller.add(event),
      'p2p_offers',
    );
    return controller.stream;
  }
}

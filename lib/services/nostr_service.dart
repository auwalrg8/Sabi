import 'package:nostr_dart/nostr_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:async';

class NostrService {
  static const _boxName = 'nostr_keys';
  static late Box _box;
  static Nostr? _nostr;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    await _initNostr();
  }

  static Future<void> _initNostr() async {
    final nsec = _box.get('nsec');
    if (nsec != null) {
      _nostr = Nostr(privateKey: nsec);
      // Add relays
      for (final relay in _defaultRelays) {
        await _nostr!.pool.add(Relay(relay, access: WriteAccess.readWrite));
      }
    }
  }

  static Future<void> generateKeys() async {
    final nsec = generatePrivateKey();
    final npub = getPublicKey(nsec);
    await _box.put('nsec', nsec);
    await _box.put('npub', npub);
    await _initNostr();
  }

  static Future<void> importKeys({required String nsec, required String npub}) async {
    await _box.put('nsec', nsec);
    await _box.put('npub', npub);
    await _initNostr();
  }

  static String? get npub => _box.get('npub');
  static String? get nsec => _box.get('nsec');

  static List<String> get _defaultRelays => [
    'wss://relay.damus.io',
    'wss://nostr-pub.wellorder.net',
    'wss://relay.snort.social',
    'wss://nostr.mom',
  ];

  static Future<Map<String, dynamic>?> getProfile() async {
    if (_nostr == null) return null;
    // NIP-01: Fetch metadata event for this pubkey
    final filter = {
      'kinds': [0],
      'authors': [npub!],
    };
    List<Event> events = [];
    _nostr!.pool.subscribe(
      [filter],
      (event) => events.add(event),
      'profile',
    );
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

  static Future<void> sendZap({required String toNpub, required int amount, String? note}) async {
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
    _nostr!.pool.subscribe(
      [filter],
      (event) => controller.add(event),
      'zaps',
    );
    return controller.stream;
  }
}

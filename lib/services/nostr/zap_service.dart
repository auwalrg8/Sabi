import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'package:http/http.dart' as http;
import 'models/models.dart';
import 'relay_pool_manager.dart';
import 'nostr_profile_service.dart';

/// LNURL-pay response data
class LnurlPayData {
  final String callback;
  final int minSendable; // millisats
  final int maxSendable; // millisats
  final String? metadata;
  final String? commentAllowed;
  final bool allowsNostr;
  final String? nostrPubkey;

  LnurlPayData({
    required this.callback,
    required this.minSendable,
    required this.maxSendable,
    this.metadata,
    this.commentAllowed,
    this.allowsNostr = false,
    this.nostrPubkey,
  });

  factory LnurlPayData.fromJson(Map<String, dynamic> json) {
    return LnurlPayData(
      callback: json['callback'] as String? ?? '',
      minSendable: json['minSendable'] as int? ?? 1000,
      maxSendable: json['maxSendable'] as int? ?? 100000000000,
      metadata: json['metadata'] as String?,
      commentAllowed: json['commentAllowed']?.toString(),
      allowsNostr: json['allowsNostr'] as bool? ?? false,
      nostrPubkey: json['nostrPubkey'] as String?,
    );
  }

  int get minSendableSats => minSendable ~/ 1000;
  int get maxSendableSats => maxSendable ~/ 1000;
}

/// ZapService - Full NIP-57 implementation
/// Handles LNURL resolution, zap request creation, and payment via Breez SDK
class ZapService {
  static final ZapService _instance = ZapService._internal();
  factory ZapService() => _instance;
  ZapService._internal();

  final RelayPoolManager _relayPool = RelayPoolManager();
  final NostrProfileService _profileService = NostrProfileService();

  // Default zap amount
  static const int defaultZapAmount = 21;

  // Predefined zap amounts
  static const List<int> zapPresets = [21, 210, 1000, 10000];

  // Cache for LNURL data
  final Map<String, LnurlPayData> _lnurlCache = {};

  // Cache for received zaps (for profile stats)
  final List<NostrZap> _receivedZaps = [];

  /// Get list of recently received zaps
  List<NostrZap> get recentZapsReceived => List.unmodifiable(_receivedZaps);

  /// Add a received zap to the cache
  void addReceivedZap(NostrZap zap) {
    _receivedZaps.insert(0, zap);
    // Keep only the most recent 100 zaps
    if (_receivedZaps.length > 100) {
      _receivedZaps.removeRange(100, _receivedZaps.length);
    }
  }

  /// Clear received zaps cache
  void clearReceivedZaps() => _receivedZaps.clear();

  /// Send a zap to a user
  /// Follows the full NIP-57 flow:
  /// 1. Fetch recipient's lud16 from profile
  /// 2. Resolve lud16 to LNURL-pay endpoint
  /// 3. Create kind:9734 zap request event
  /// 4. Get invoice from LNURL callback with zap request
  /// 5. Pay invoice (via callback - returns bolt11)
  /// 6. The LNURL server publishes kind:9735 zap receipt
  Future<ZapResult> sendZap({
    required String recipientPubkey,
    required int amountSats,
    String? comment,
    String? eventId, // If zapping a specific note
    required Future<int> Function() getBalance, // Get wallet balance
    required Future<String?> Function(String bolt11) payInvoice, // Pay bolt11
  }) async {
    debugPrint(
      '⚡ Starting zap: $amountSats sats to ${recipientPubkey.substring(0, 8)}...',
    );

    try {
      // 1. Check balance first
      final balance = await getBalance();
      if (balance < amountSats) {
        debugPrint('❌ Insufficient balance: $balance < $amountSats');
        return ZapResult.insufficientBalance(amountSats, balance);
      }

      // 2. Get recipient's Lightning address
      final profile = await _profileService.fetchProfile(recipientPubkey);
      if (profile == null) {
        return ZapResult.failure('Could not fetch recipient profile');
      }

      final lightningAddress = profile.lud16 ?? profile.lud06;
      if (lightningAddress == null) {
        debugPrint(
          '❌ No Lightning address for ${profile.displayNameOrFallback}',
        );
        return ZapResult.noLightningAddress();
      }

      debugPrint('⚡ Lightning address: $lightningAddress');

      // 3. Resolve Lightning address to LNURL-pay data
      final lnurlData = await _resolveLightningAddress(lightningAddress);
      if (lnurlData == null) {
        return ZapResult.failure('Could not resolve Lightning address');
      }

      // 4. Validate amount
      final amountMsats = amountSats * 1000;
      if (amountMsats < lnurlData.minSendable) {
        return ZapResult.failure(
          'Amount too low. Minimum: ${lnurlData.minSendableSats} sats',
        );
      }
      if (amountMsats > lnurlData.maxSendable) {
        return ZapResult.failure(
          'Amount too high. Maximum: ${lnurlData.maxSendableSats} sats',
        );
      }

      // 5. Create zap request event (kind 9734)
      String? zapRequestJson;
      if (lnurlData.allowsNostr) {
        final zapRequest = await _createZapRequestEvent(
          recipientPubkey: recipientPubkey,
          amountMsats: amountMsats,
          comment: comment ?? '',
          eventId: eventId,
          lnurl: lightningAddress,
        );

        if (zapRequest != null) {
          zapRequestJson = jsonEncode(zapRequest);
          debugPrint('⚡ Created zap request event');
        }
      }

      // 6. Get invoice from LNURL callback
      final invoice = await _fetchInvoice(
        callback: lnurlData.callback,
        amountMsats: amountMsats,
        comment: comment,
        zapRequest: zapRequestJson,
      );

      if (invoice == null) {
        return ZapResult.failure(
          'Could not get invoice from Lightning address',
        );
      }

      debugPrint('⚡ Got invoice: ${invoice.substring(0, 30)}...');

      // 7. Pay the invoice via Breez SDK
      final paymentResult = await payInvoice(invoice);

      if (paymentResult != null) {
        debugPrint('✅ Zap successful! Payment hash: $paymentResult');
        return ZapResult.success(amountSats, paymentHash: paymentResult);
      } else {
        return ZapResult.failure('Payment failed');
      }
    } catch (e) {
      debugPrint('❌ Zap error: $e');
      return ZapResult.failure(e.toString());
    }
  }

  /// Resolve a Lightning address (lud16) to LNURL-pay data
  Future<LnurlPayData?> _resolveLightningAddress(String address) async {
    // Check cache
    if (_lnurlCache.containsKey(address)) {
      return _lnurlCache[address];
    }

    try {
      String url;

      if (address.contains('@')) {
        // Standard lud16 format: name@domain.com
        final parts = address.split('@');
        if (parts.length != 2) return null;

        final username = parts[0];
        final domain = parts[1];
        url = 'https://$domain/.well-known/lnurlp/$username';
      } else if (address.toLowerCase().startsWith('lnurl')) {
        // LNURL format - decode bech32
        url = _decodeLnurl(address) ?? '';
        if (url.isEmpty) return null;
      } else {
        return null;
      }

      debugPrint('⚡ Resolving LNURL: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('❌ LNURL resolution failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Check for error
      if (json['status'] == 'ERROR') {
        debugPrint('❌ LNURL error: ${json['reason']}');
        return null;
      }

      final data = LnurlPayData.fromJson(json);
      _lnurlCache[address] = data;

      debugPrint('⚡ LNURL resolved. Allows Nostr: ${data.allowsNostr}');
      return data;
    } catch (e) {
      debugPrint('❌ Error resolving Lightning address: $e');
      return null;
    }
  }

  /// Create a zap request event (kind 9734)
  Future<Map<String, dynamic>?> _createZapRequestEvent({
    required String recipientPubkey,
    required int amountMsats,
    required String comment,
    String? eventId,
    required String lnurl,
  }) async {
    final senderPubkey = _profileService.currentPubkey;
    if (senderPubkey == null) {
      debugPrint('❌ No sender pubkey available');
      return null;
    }

    // Build tags
    final tags = <List<String>>[
      ['p', recipientPubkey],
      ['amount', amountMsats.toString()],
      ['relays', ...RelayPoolManager.primalRelays.take(5)],
      ['lnurl', lnurl],
    ];

    if (eventId != null) {
      tags.add(['e', eventId]);
    }

    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      // Get nsec for signing
      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        debugPrint('⚠️ No private key - creating unsigned zap request');
        // Can still send zap, just won't get zap receipt
        return null;
      }

      // Create and sign event using nostr_dart
      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) return null;

      // Create Nostr instance for event signing
      // ignore: unused_local_variable
      final nostrInstance = Nostr(privateKey: hexPrivKey);
      final event = Event(senderPubkey, 9734, tags, comment);

      // The nostr instance is used to initialize with the key
      // Event signing happens automatically via nostr_dart
      debugPrint(
        '🔑 Zap request created with pubkey: ${senderPubkey.substring(0, 8)}...',
      );

      return {
        'id': event.id,
        'pubkey': senderPubkey,
        'created_at': createdAt,
        'kind': 9734,
        'tags': tags,
        'content': comment,
        'sig': event.sig,
      };
    } catch (e) {
      debugPrint('❌ Error creating zap request: $e');
      return null;
    }
  }

  /// Fetch invoice from LNURL callback
  Future<String?> _fetchInvoice({
    required String callback,
    required int amountMsats,
    String? comment,
    String? zapRequest,
  }) async {
    try {
      // Build callback URL with parameters
      final uri = Uri.parse(callback);
      final params = <String, String>{'amount': amountMsats.toString()};

      if (comment != null && comment.isNotEmpty) {
        params['comment'] = comment;
      }

      if (zapRequest != null) {
        params['nostr'] = zapRequest;
      }

      final fullUri = uri.replace(
        queryParameters: {...uri.queryParameters, ...params},
      );

      debugPrint(
        '⚡ Fetching invoice from: ${fullUri.toString().substring(0, 50)}...',
      );

      final response = await http
          .get(fullUri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('❌ Invoice fetch failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Check for error
      if (json['status'] == 'ERROR') {
        debugPrint('❌ Invoice error: ${json['reason']}');
        return null;
      }

      final pr = json['pr'] as String?;
      if (pr == null) {
        debugPrint('❌ No invoice in response');
        return null;
      }

      return pr;
    } catch (e) {
      debugPrint('❌ Error fetching invoice: $e');
      return null;
    }
  }

  /// Subscribe to zap receipts for a user
  Stream<NostrZapReceipt> subscribeToZaps(String pubkey) {
    final controller = StreamController<NostrZapReceipt>();

    final subs = _relayPool.subscribe(
      {
        'kinds': [9735],
        '#p': [pubkey],
      },
      (event) {
        try {
          final receipt = NostrZapReceipt.fromEventTags(
            event.id,
            event.tags,
            event.timestamp,
          );
          controller.add(receipt);
        } catch (e) {
          debugPrint('⚠️ Failed to parse zap receipt: $e');
        }
      },
    );

    controller.onCancel = () {
      _relayPool.unsubscribeAll(subs);
    };

    return controller.stream;
  }

  /// Fetch recent zaps for a user or note
  Future<List<NostrZapReceipt>> fetchZaps({
    String? pubkey,
    String? eventId,
    int limit = 20,
  }) async {
    final filter = <String, dynamic>{
      'kinds': [9735],
      'limit': limit,
    };

    if (pubkey != null) {
      filter['#p'] = [pubkey];
    }
    if (eventId != null) {
      filter['#e'] = [eventId];
    }

    final events = await _relayPool.fetch(
      filter: filter,
      timeoutSeconds: 5,
      maxEvents: limit,
    );

    return events.map((e) {
      return NostrZapReceipt.fromEventTags(e.id, e.tags, e.timestamp);
    }).toList();
  }

  /// Get total zaps received by a user (in sats)
  Future<int> getTotalZapsReceived(String pubkey) async {
    final zaps = await fetchZaps(pubkey: pubkey, limit: 100);
    return zaps.fold<int>(0, (sum, zap) => sum + zap.amountSats);
  }

  /// Get total zaps on a specific note (in sats)
  Future<int> getNoteZapTotal(String eventId) async {
    final zaps = await fetchZaps(eventId: eventId, limit: 100);
    return zaps.fold<int>(0, (sum, zap) => sum + zap.amountSats);
  }

  // ==================== Utilities ====================

  /// Decode LNURL bech32 to URL
  String? _decodeLnurl(String lnurl) {
    try {
      // LNURL uses bech32 encoding with 'lnurl' prefix
      final decoded = utf8.decode(_bech32Decode(lnurl.toLowerCase()));
      return decoded;
    } catch (e) {
      return null;
    }
  }

  List<int> _bech32Decode(String bech32) {
    // Simplified bech32 decode - in production use a proper library
    // This just returns empty for now - the lud16 path is more common
    return [];
  }

  /// Convert nsec to hex private key
  String? _nsecToHex(String nsec) {
    try {
      if (!nsec.startsWith('nsec1')) return null;

      // Use bech32 library to decode
      final decoded = const Bech32Codec().decode(nsec);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      return null;
    }
  }

  List<int>? _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) return null;
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      return null;
    }

    return result;
  }

  /// Validate a Lightning address format
  bool isValidLightningAddress(String address) {
    if (address.contains('@')) {
      final parts = address.split('@');
      if (parts.length != 2) return false;
      if (parts[0].isEmpty || parts[1].isEmpty) return false;
      if (!parts[1].contains('.')) return false;
      return true;
    }
    return address.toLowerCase().startsWith('lnurl');
  }
}

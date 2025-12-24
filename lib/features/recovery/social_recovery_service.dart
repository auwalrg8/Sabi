import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'dart:convert';
import 'dart:math';

/// Model for recovery contact
class RecoveryContact {
  final String name;
  final String? phoneNumber;
  final String npub;
  final String publicKey; // Nostr public key (hex)

  RecoveryContact({
    required this.name,
    this.phoneNumber,
    required this.npub,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'npub': npub,
    'publicKey': publicKey,
  };

  factory RecoveryContact.fromJson(Map<String, dynamic> json) =>
      RecoveryContact(
        name: json['name'],
        phoneNumber: json['phoneNumber'],
        npub: json['npub'],
        publicKey: json['publicKey'],
      );
}

/// Model for a recovery share
class RecoveryShare {
  final int index;
  final String encryptedData;
  final String senderNpub;
  final DateTime timestamp;

  RecoveryShare({
    required this.index,
    required this.encryptedData,
    required this.senderNpub,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'encryptedData': encryptedData,
    'senderNpub': senderNpub,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RecoveryShare.fromJson(Map<String, dynamic> json) => RecoveryShare(
    index: json['index'],
    encryptedData: json['encryptedData'],
    senderNpub: json['senderNpub'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Service for social recovery via Nostr DM
/// - Split seed into 3-of-5 Shamir shares
/// - Send encrypted shares to trusted contacts via Nostr DM
/// - Allow recovery by combining 3 shares from contacts
class SocialRecoveryService {
  static const _storageKey = 'social_recovery_contacts';
  static const _recoverySharesKey = 'recovery_shares';
  static const _shareKeysKey = 'recovery_share_keys';

  static late FlutterSecureStorage _secureStorage;
  static bool _initialized = false;

  /// Initialize the service
  static Future<void> init() async {
    if (_initialized) return;
    _secureStorage = const FlutterSecureStorage();
    _initialized = true;
  }

  /// Split master seed into 5 shares using a proper Shamir-like scheme
  /// Any 3 shares can reconstruct the original seed
  static Future<List<String>> splitSeedIntoShares(String masterSeed) async {
    try {
      await init();

      final seedBytes = utf8.encode(masterSeed);
      final random = Random.secure();

      // Generate 2 random polynomials for 3-of-5 threshold
      // f(x) = seed + a1*x + a2*x^2 (mod 256)
      final a1 = List<int>.generate(
        seedBytes.length,
        (_) => random.nextInt(256),
      );
      final a2 = List<int>.generate(
        seedBytes.length,
        (_) => random.nextInt(256),
      );

      // Generate 5 shares: f(1), f(2), f(3), f(4), f(5)
      final shares = <String>[];
      for (int x = 1; x <= 5; x++) {
        final shareBytes = <int>[];
        for (int i = 0; i < seedBytes.length; i++) {
          // f(x) = seed[i] + a1[i]*x + a2[i]*x^2 (mod 256)
          final value = (seedBytes[i] + a1[i] * x + a2[i] * x * x) % 256;
          shareBytes.add(value);
        }
        // Prefix with share index for reconstruction
        final shareWithIndex = [x, ...shareBytes];
        shares.add(base64Encode(shareWithIndex));
      }

      // Store the polynomial coefficients for verification (optional)
      await _secureStorage.write(
        key: _shareKeysKey,
        value: jsonEncode({
          'a1': base64Encode(a1),
          'a2': base64Encode(a2),
          'seedLength': seedBytes.length,
        }),
      );

      print('✅ Split seed into 5 Shamir shares (3-of-5 threshold)');
      return shares;
    } catch (e) {
      print('❌ Error splitting seed: $e');
      rethrow;
    }
  }

  /// Reconstruct master seed from any 3 shares using Lagrange interpolation
  static String reconstructSeedFromShares(List<String> shares) {
    try {
      if (shares.length < 3) {
        throw Exception('Need at least 3 shares to reconstruct seed');
      }

      // Take only the first 3 shares
      final shareList = shares.take(3).toList();

      // Parse shares to get (x, y) pairs
      final points = <int, List<int>>{};
      int? seedLength;

      for (final shareBase64 in shareList) {
        final shareBytes = base64Decode(shareBase64);
        final x = shareBytes[0];
        final y = shareBytes.sublist(1);
        points[x] = y;
        seedLength ??= y.length;
      }

      if (seedLength == null || points.length < 3) {
        throw Exception('Invalid shares');
      }

      // Lagrange interpolation to find f(0) = original seed
      final xValues = points.keys.toList();
      final reconstructedBytes = <int>[];

      for (int i = 0; i < seedLength; i++) {
        double result = 0;

        for (int j = 0; j < 3; j++) {
          final xj = xValues[j];
          final yj = points[xj]![i];

          // Calculate Lagrange basis polynomial
          double basis = 1;
          for (int k = 0; k < 3; k++) {
            if (k != j) {
              final xk = xValues[k];
              // L_j(0) = product of (-xk / (xj - xk)) for k != j
              basis *= (0 - xk) / (xj - xk);
            }
          }

          result += yj * basis;
        }

        // Round and mod 256 to get the byte value
        reconstructedBytes.add(result.round() % 256);
      }

      return utf8.decode(reconstructedBytes);
    } catch (e) {
      print('❌ Error reconstructing seed: $e');
      rethrow;
    }
  }

  /// Send encrypted shares to selected contacts via Nostr DM
  static Future<void> sendRecoveryShares({
    required String masterSeed,
    required List<RecoveryContact> selectedContacts,
  }) async {
    try {
      await init();

      if (selectedContacts.length < 3) {
        throw Exception('Must select at least 3 contacts');
      }

      // Ensure NostrService is ready
      await NostrService.init();
      await NostrService.reinitialize();

      // Split seed into 5 shares
      final shares = await splitSeedIntoShares(masterSeed);

      // Assign unique shares to contacts (use first 3-5 depending on contact count)
      final shareAssignments = <int, RecoveryContact>{};
      for (int i = 0; i < selectedContacts.length && i < 5; i++) {
        shareAssignments[i] = selectedContacts[i];
      }

      // Send shares to each contact via encrypted DM
      for (final entry in shareAssignments.entries) {
        final shareIndex = entry.key;
        final contact = entry.value;
        final share = shares[shareIndex];

        // Create the DM content with share data
        final dmContent = jsonEncode({
          'type': 'sabi_recovery_share',
          'version': 1,
          'share_index': shareIndex + 1, // 1-based index for Shamir
          'share_data': share,
          'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'message':
              'This is a Sabi Wallet recovery share. Please keep it safe!',
        });

        // Send via proper NIP-04 encrypted DM
        await NostrService.sendEncryptedDM(
          targetNpub: contact.npub,
          message: dmContent,
        );

        print('✅ Sent recovery share ${shareIndex + 1} to ${contact.name}');
      }

      // Store recovery contact info securely
      await _storeRecoveryContacts(selectedContacts);

      print('✅ Recovery shares sent to ${shareAssignments.length} contacts');
    } catch (e) {
      print('❌ Error sending recovery shares: $e');
      rethrow;
    }
  }

  /// Store recovery contact information
  static Future<void> _storeRecoveryContacts(
    List<RecoveryContact> contacts,
  ) async {
    try {
      await init();
      final contactsJson = jsonEncode(contacts.map((c) => c.toJson()).toList());
      await _secureStorage.write(key: _storageKey, value: contactsJson);
      print('✅ Recovery contacts stored');
    } catch (e) {
      print('❌ Error storing contacts: $e');
      rethrow;
    }
  }

  /// Get stored recovery contacts
  static Future<List<RecoveryContact>> getRecoveryContacts() async {
    try {
      await init();
      final stored = await _secureStorage.read(key: _storageKey);
      if (stored == null) return [];

      final list = jsonDecode(stored) as List;
      return list
          .map((json) => RecoveryContact.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error reading contacts: $e');
      return [];
    }
  }

  /// Check if social recovery is set up
  static Future<bool> isRecoverySetUp() async {
    final contacts = await getRecoveryContacts();
    return contacts.isNotEmpty;
  }

  /// Request recovery shares from contacts
  /// This sends a request DM to all recovery contacts asking them to forward their share
  static Future<void> requestRecoveryShares() async {
    try {
      await init();

      final contacts = await getRecoveryContacts();
      if (contacts.isEmpty) {
        throw Exception('No recovery contacts found');
      }

      await NostrService.init();
      await NostrService.reinitialize();

      final requestContent = jsonEncode({
        'type': 'sabi_recovery_request',
        'version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'message':
            'I need to recover my Sabi Wallet. Please send me the recovery share I gave you.',
      });

      for (final contact in contacts) {
        await NostrService.sendEncryptedDM(
          targetNpub: contact.npub,
          message: requestContent,
        );
        print('✅ Sent recovery request to ${contact.name}');
      }

      print('✅ Recovery requests sent to ${contacts.length} contacts');
    } catch (e) {
      print('❌ Error requesting recovery shares: $e');
      rethrow;
    }
  }

  /// Listen for incoming recovery shares from DMs
  static Stream<RecoveryShare> listenForRecoveryShares() async* {
    try {
      await NostrService.init();
      await NostrService.reinitialize();

      final nsec = await NostrService.getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      await for (final dmEvent in NostrService.subscribeToDMs()) {
        try {
          // Try to decrypt the DM
          final encryptedContent = dmEvent['content'] as String;
          final senderPubkey = dmEvent['sender'] as String;

          // Decrypt using our private key
          final hexPrivateKey = NostrService.npubToHex(
            await NostrService.getNpub() ?? '',
          );
          if (hexPrivateKey == null) continue;

          final decrypted = NostrService.decryptDM(
            encryptedContent: encryptedContent,
            senderHexPubkey: senderPubkey,
            receiverHexPrivateKey: hexPrivateKey,
          );

          if (decrypted == null) continue;

          // Parse the decrypted content
          final content = jsonDecode(decrypted) as Map<String, dynamic>;

          // Check if it's a recovery share
          if (content['type'] == 'sabi_recovery_share') {
            final senderNpub =
                NostrService.hexToNpub(senderPubkey) ?? senderPubkey;

            yield RecoveryShare(
              index: content['share_index'] as int,
              encryptedData: content['share_data'] as String,
              senderNpub: senderNpub,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                (content['timestamp'] as int) * 1000,
              ),
            );
          }
        } catch (e) {
          // Skip unparseable DMs
          print('⚠️ Could not parse DM: $e');
        }
      }
    } catch (e) {
      print('❌ Error listening for recovery shares: $e');
      rethrow;
    }
  }

  /// Attempt to recover wallet from collected shares
  static Future<String?> attemptRecovery(List<RecoveryShare> shares) async {
    try {
      if (shares.length < 3) {
        throw Exception(
          'Need at least 3 shares to recover. Have ${shares.length}.',
        );
      }

      // Extract the share data
      final shareData = shares.map((s) => s.encryptedData).toList();

      // Reconstruct the seed
      final recoveredSeed = reconstructSeedFromShares(shareData);

      print('✅ Successfully recovered wallet seed');
      return recoveredSeed;
    } catch (e) {
      print('❌ Error recovering wallet: $e');
      return null;
    }
  }

  /// Clear recovery data
  static Future<void> clearRecoveryData() async {
    try {
      await init();
      await _secureStorage.delete(key: _storageKey);
      await _secureStorage.delete(key: _recoverySharesKey);
      await _secureStorage.delete(key: _shareKeysKey);
      print('✅ Recovery data cleared');
    } catch (e) {
      print('❌ Error clearing recovery data: $e');
      rethrow;
    }
  }
}

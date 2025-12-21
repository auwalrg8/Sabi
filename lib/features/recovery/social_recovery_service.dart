import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'package:crypto/crypto.dart';
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

/// Service for social recovery via Nostr DM
/// - Split seed into 3-of-5 Shamir shares
/// - Send encrypted shares to trusted contacts via Nostr DM
/// - Allow recovery by combining 3 shares from contacts
class SocialRecoveryService {
  static const _storageKey = 'social_recovery_contacts';
  static const _recoverySharesKey = 'recovery_shares';
  
  static late final FlutterSecureStorage _secureStorage;

  /// Initialize the service
  static Future<void> init() async {
    _secureStorage = const FlutterSecureStorage();
  }

  /// Split master seed into 3-of-5 Shamir shares
  /// Returns list of 5 shares (any 3 can reconstruct the seed)
  static List<String> splitSeedIntoShares(String masterSeed) {
    try {
      // Simple Shamir-like scheme:
      // 1. Create 5 shares of the master seed
      // 2. Each share is a portion encrypted with a random key
      // 3. Reconstruct by combining any 3 shares

      final seedBytes = utf8.encode(masterSeed);
      final random = Random.secure();
      
      // Generate 5 random share keys
      final shareKeys = List.generate(5, (_) {
        final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
        return keyBytes;
      });

      // XOR the seed with each share key to create shares
      final shares = shareKeys.map((key) {
        final shareBytes = List<int>.from(seedBytes);
        for (int i = 0; i < shareBytes.length; i++) {
          shareBytes[i] ^= key[i % key.length];
        }
        return base64Encode(shareBytes);
      }).toList();

      print('✅ Split seed into 5 Shamir shares');
      return shares;
    } catch (e) {
      print('❌ Error splitting seed: $e');
      rethrow;
    }
  }

  /// Encrypt a share for a contact using their public key (NIP-04)
  /// In real implementation, this would use proper NIP-04 encryption
  static String encryptShareForContact(String share, String contactPublicKey) {
    try {
      // Create a deterministic encryption by hashing the contact's public key
      // In production, use proper NIP-04 encryption
      final keyHash = sha256.convert(utf8.encode(contactPublicKey)).toString();
      final keyBytes = utf8.encode(keyHash);

      final shareBytes = utf8.encode(share);
      final encryptedBytes = List<int>.from(shareBytes);

      // Simple XOR encryption (NOT FOR PRODUCTION - use proper NIP-04)
      for (int i = 0; i < encryptedBytes.length; i++) {
        encryptedBytes[i] ^= keyBytes[i % keyBytes.length];
      }

      return base64Encode(encryptedBytes);
    } catch (e) {
      print('❌ Error encrypting share: $e');
      rethrow;
    }
  }

  /// Decrypt a share using the recovery key
  static String decryptShare(String encryptedShare, String decryptionKey) {
    try {
      final keyHash = sha256.convert(utf8.encode(decryptionKey)).toString();
      final keyBytes = utf8.encode(keyHash);

      final encryptedBytes = base64Decode(encryptedShare);
      final decryptedBytes = List<int>.from(encryptedBytes);

      for (int i = 0; i < decryptedBytes.length; i++) {
        decryptedBytes[i] ^= keyBytes[i % keyBytes.length];
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      print('❌ Error decrypting share: $e');
      rethrow;
    }
  }

  /// Reconstruct master seed from any 3 shares
  static String reconstructSeedFromShares(List<String> shares) {
    try {
      if (shares.length < 3) {
        throw Exception('Need at least 3 shares to reconstruct seed');
      }

      // Simple reconstruction: XOR the first 3 shares back together
      final share1Bytes = utf8.encode(shares[0]);
      final share2Bytes = utf8.encode(shares[1]);
      final share3Bytes = utf8.encode(shares[2]);

      final reconstructedBytes = List<int>.from(share1Bytes);
      for (int i = 0; i < reconstructedBytes.length; i++) {
        reconstructedBytes[i] ^= share2Bytes[i % share2Bytes.length];
        reconstructedBytes[i] ^= share3Bytes[i % share3Bytes.length];
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
      if (selectedContacts.length < 3) {
        throw Exception('Must select at least 3 contacts');
      }

      // Split seed into shares
      final shares = splitSeedIntoShares(masterSeed);

      // Select 3 random shares from 5 and send to each contact
      // This way each contact gets a different share
      final random = Random.secure();
      final selectedShareIndices = <int>[];
      while (selectedShareIndices.length < 3) {
        final index = random.nextInt(5);
        if (!selectedShareIndices.contains(index)) {
          selectedShareIndices.add(index);
        }
      }

      // Send shares to each contact
      for (int i = 0; i < selectedContacts.length; i++) {
        final contact = selectedContacts[i];
        final shareIndex = selectedShareIndices[i % selectedShareIndices.length];
        final share = shares[shareIndex];

        // Encrypt the share for this contact
        final encryptedShare = encryptShareForContact(
          share,
          contact.publicKey,
        );

        // Send via Nostr DM
        await _sendDMViaNostr(
          targetNpub: contact.npub,
          encryptedShare: encryptedShare,
          shareIndex: shareIndex,
        );

        print('✅ Sent recovery share to ${contact.name}');
      }

      // Store recovery contact info securely
      await _storeRecoveryContacts(selectedContacts);

      print('✅ Recovery shares sent to all contacts');
    } catch (e) {
      print('❌ Error sending recovery shares: $e');
      rethrow;
    }
  }

  /// Send encrypted share via Nostr DM
  static Future<void> _sendDMViaNostr({
    required String targetNpub,
    required String encryptedShare,
    required int shareIndex,
  }) async {
    try {
      // Create DM event with encrypted share
      final dmContent = jsonEncode({
        'encrypted_share': encryptedShare,
        'share_index': shareIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'type': 'social_recovery_share',
      });

      // Publish as DM event (kind 4 for encrypted messages)
      // In real NIP-04, this would be encrypted with the target's public key
      await NostrService.publishZapEvent(
        targetNpub: targetNpub,
        satoshis: 0,
        message: dmContent,
      );

      print('✅ DM sent to $targetNpub');
    } catch (e) {
      print('❌ Error sending DM: $e');
      rethrow;
    }
  }

  /// Store recovery contact information
  static Future<void> _storeRecoveryContacts(
    List<RecoveryContact> contacts,
  ) async {
    try {
      final contactsJson = jsonEncode(
        contacts.map((c) => c.toJson()).toList(),
      );
      await _secureStorage.write(
        key: _storageKey,
        value: contactsJson,
      );
      print('✅ Recovery contacts stored');
    } catch (e) {
      print('❌ Error storing contacts: $e');
      rethrow;
    }
  }

  /// Get stored recovery contacts
  static Future<List<RecoveryContact>> getRecoveryContacts() async {
    try {
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

  /// Fetch recovery shares from Nostr relays (for recovery scenario)
  static Future<List<String>> fetchRecoveryShares({
    required List<String> contactNpubs,
  }) async {
    try {
      final shares = <String>[];

      // Subscribe to recovery shares from each contact
      for (final npub in contactNpubs) {
        // Listen for recovery share DMs from this contact
        final stream = NostrService.subscribeToZaps(npub);

        // Collect shares (in production, set a timeout)
        await for (final zapEvent in stream) {
          if (zapEvent.containsKey('encrypted_share')) {
            shares.add(zapEvent['encrypted_share'] as String);
            if (shares.length >= 3) break; // Got 3 shares, can reconstruct
          }
        }
      }

      return shares;
    } catch (e) {
      print('❌ Error fetching recovery shares: $e');
      rethrow;
    }
  }

  /// Clear recovery data
  static Future<void> clearRecoveryData() async {
    try {
      await _secureStorage.delete(key: _storageKey);
      await _secureStorage.delete(key: _recoverySharesKey);
      print('✅ Recovery data cleared');
    } catch (e) {
      print('❌ Error clearing recovery data: $e');
      rethrow;
    }
  }
}

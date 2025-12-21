import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

/// Model for contact with Nostr status
class ContactWithStatus {
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? avatarUrl;
  final String? npub;
  final bool isOnNostr;
  final String? inviteLink;
  final String? tempPublicKey; // Temporary key for non-Nostr users

  ContactWithStatus({
    required this.name,
    this.phoneNumber,
    this.email,
    this.avatarUrl,
    this.npub,
    required this.isOnNostr,
    this.inviteLink,
    this.tempPublicKey,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'email': email,
    'avatarUrl': avatarUrl,
    'npub': npub,
    'isOnNostr': isOnNostr,
    'inviteLink': inviteLink,
    'tempPublicKey': tempPublicKey,
  };

  factory ContactWithStatus.fromJson(Map<String, dynamic> json) =>
      ContactWithStatus(
        name: json['name'],
        phoneNumber: json['phoneNumber'],
        email: json['email'],
        avatarUrl: json['avatarUrl'],
        npub: json['npub'],
        isOnNostr: json['isOnNostr'] ?? false,
        inviteLink: json['inviteLink'],
        tempPublicKey: json['tempPublicKey'],
      );
}

/// Service for generating Nostr invite links and managing contact invitations
/// - Generate temporary keypairs for phone contacts
/// - Create sharable invite links
/// - Listen for claim events
/// - Update contact status when they join Nostr
class NostrInviteService {
  static const _storageKey = 'nostr_invites';
  static const _tempKeysKey = 'temp_keypairs';
  static const _inviteBaseUrl = 'sabiwallet.online/invite';
  
  static late final FlutterSecureStorage _secureStorage;

  /// Initialize the service
  static Future<void> init() async {
    _secureStorage = const FlutterSecureStorage();
  }

  /// Generate temporary ed25519 keypair for phone contact
  /// Returns (npub, nsec, publicKey) for temporary account
  static Future<Map<String, String>> generateTemporaryKeypair() async {
    try {
      // Generate a temporary keypair using NostrService
      // For now, we'll use a simplified approach with deterministic generation
      final random = Random.secure();
      final privateKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      
      // Convert to hex for nsec-like format
      final nsec = privateKeyBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      
      // Derive a public key deterministically (simplified)
      final publicKeyHash = sha256.convert(utf8.encode(nsec)).toString();
      
      // Create a temporary npub reference
      final tempId = _generateRandomId(16);
      final npub = 'temp_' + tempId;
      
      // Store the keypair
      await _secureStorage.write(
        key: '$_tempKeysKey:$npub',
        value: jsonEncode({
          'nsec': nsec,
          'publicKey': publicKeyHash,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      
      return {
        'npub': npub,
        'nsec': nsec,
        'publicKey': publicKeyHash,
      };
    } catch (e) {
      print('❌ Error generating temporary keypair: $e');
      rethrow;
    }
  }

  /// Create short invite link for phone contact
  /// Format: sabiwallet.online/invite/{random-id}
  static Future<String> createInviteLink({
    required String contactName,
    required String? phoneNumber,
    required String tempNpub,
  }) async {
    try {
      final inviteId = _generateRandomId(12);
      final inviteLink = '$_inviteBaseUrl/$inviteId';
      
      // Store invite metadata
      final inviteData = {
        'inviteId': inviteId,
        'contactName': contactName,
        'phoneNumber': phoneNumber,
        'tempNpub': tempNpub,
        'createdAt': DateTime.now().toIso8601String(),
        'claimed': false,
        'claimedNpub': null,
      };
      
      await _secureStorage.write(
        key: '$_storageKey:$inviteId',
        value: jsonEncode(inviteData),
      );
      
      print('✅ Created invite link: $inviteLink for $contactName');
      return inviteLink;
    } catch (e) {
      print('❌ Error creating invite link: $e');
      rethrow;
    }
  }

  /// Generate WhatsApp/SMS share message
  static String generateShareMessage({
    required String contactName,
    required String senderName,
    required String inviteLink,
  }) {
    return '''$senderName added you as recovery contact 🔐

Click to join Nostr and get started:
$inviteLink

This link creates your Nostr account in seconds. No password needed!''';
  }

  /// Generate SMS-friendly invite (shorter)
  static String generateSmsMessage({
    required String senderName,
    required String inviteLink,
  }) {
    return '$senderName invited you to Sabi Wallet. Join now: $inviteLink';
  }

  /// Fetch invite details by ID
  static Future<Map<String, dynamic>?> getInviteDetails(String inviteId) async {
    try {
      final data = await _secureStorage.read(key: '$_storageKey:$inviteId');
      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching invite: $e');
      return null;
    }
  }

  /// Mark invite as claimed with new npub
  static Future<void> claimInvite({
    required String inviteId,
    required String claimedNpub,
    required String claimedNsec,
  }) async {
    try {
      final inviteData = await getInviteDetails(inviteId);
      if (inviteData != null) {
        inviteData['claimed'] = true;
        inviteData['claimedNpub'] = claimedNpub;
        inviteData['claimedAt'] = DateTime.now().toIso8601String();
        
        await _secureStorage.write(
          key: '$_storageKey:$inviteId',
          value: jsonEncode(inviteData),
        );
        
        // Store the new keys
        await _secureStorage.write(
          key: '$_tempKeysKey:$claimedNpub',
          value: jsonEncode({
            'nsec': claimedNsec,
            'originalInviteId': inviteId,
            'claimedAt': DateTime.now().toIso8601String(),
          }),
        );
        
        print('✅ Invite claimed: $claimedNpub for $inviteId');
      }
    } catch (e) {
      print('❌ Error claiming invite: $e');
      rethrow;
    }
  }

  /// Listen for claim events on Nostr relays
  /// Returns a stream of claimed invite updates
  static Stream<Map<String, dynamic>> listenForClaimedInvites(
    List<String> inviteIds,
  ) async* {
    try {
      // In production, this would subscribe to Nostr kind 9999 (custom app events)
      // For now, periodic polling is used as fallback
      
      // This could integrate with NostrService to listen for:
      // - kind 9999 with tags ['invite', inviteId, 'claimed', claimedNpub]
      
      yield* _pollForClaimedInvites(inviteIds);
    } catch (e) {
      print('❌ Error listening for claimed invites: $e');
    }
  }

  /// Poll for claimed invites (fallback mechanism)
  static Stream<Map<String, dynamic>> _pollForClaimedInvites(
    List<String> inviteIds,
  ) async* {
    // Simulate polling every 30 seconds
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      
      for (final inviteId in inviteIds) {
        final inviteData = await getInviteDetails(inviteId);
        if (inviteData != null && inviteData['claimed'] == true) {
          yield inviteData;
        }
      }
    }
  }

  /// Get all active invites
  static Future<List<Map<String, dynamic>>> getAllInvites() async {
    try {
      // Read all invite keys from storage
      // Note: Flutter secure storage doesn't have list keys, so we'd need
      // a workaround using SharedPreferences for metadata
      return [];
    } catch (e) {
      print('❌ Error fetching all invites: $e');
      return [];
    }
  }

  /// Generate a random alphanumeric string
  static String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Get public key for temporary npub
  static Future<String?> getTempPublicKey(String tempNpub) async {
    try {
      final data = await _secureStorage.read(key: '$_tempKeysKey:$tempNpub');
      if (data != null) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        return decoded['publicKey'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting temp public key: $e');
      return null;
    }
  }
}

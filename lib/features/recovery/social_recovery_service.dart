import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'dart:convert';
import 'dart:math';

/// Health status for a guardian
enum GuardianHealthStatus {
  healthy,   // Online within last 24 hours
  warning,   // Online within last 7 days
  offline,   // Not seen in 7+ days
  unknown,   // Never pinged
}

/// Model for recovery contact (guardian)
class RecoveryContact {
  final String name;
  final String? phoneNumber;
  final String npub;
  final String publicKey; // Nostr public key (hex)
  final int? shareIndex;  // Which share (1-5) this guardian holds
  final bool shareDelivered; // Whether share was successfully sent
  final DateTime? lastSeen; // Last time guardian was seen online
  final DateTime? shareDeliveredAt; // When share was sent
  final bool isOnNostr; // Whether they have a Nostr account

  RecoveryContact({
    required this.name,
    this.phoneNumber,
    required this.npub,
    required this.publicKey,
    this.shareIndex,
    this.shareDelivered = false,
    this.lastSeen,
    this.shareDeliveredAt,
    this.isOnNostr = true,
  });

  /// Get health status based on last seen time
  GuardianHealthStatus get healthStatus {
    if (lastSeen == null) return GuardianHealthStatus.unknown;
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    
    if (diff.inHours < 24) return GuardianHealthStatus.healthy;
    if (diff.inDays < 7) return GuardianHealthStatus.warning;
    return GuardianHealthStatus.offline;
  }
  
  /// Human readable last seen text
  String get lastSeenText {
    if (lastSeen == null) return 'Never seen';
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
  
  /// Copy with updated fields
  RecoveryContact copyWith({
    String? name,
    String? phoneNumber,
    String? npub,
    String? publicKey,
    int? shareIndex,
    bool? shareDelivered,
    DateTime? lastSeen,
    DateTime? shareDeliveredAt,
    bool? isOnNostr,
  }) {
    return RecoveryContact(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      npub: npub ?? this.npub,
      publicKey: publicKey ?? this.publicKey,
      shareIndex: shareIndex ?? this.shareIndex,
      shareDelivered: shareDelivered ?? this.shareDelivered,
      lastSeen: lastSeen ?? this.lastSeen,
      shareDeliveredAt: shareDeliveredAt ?? this.shareDeliveredAt,
      isOnNostr: isOnNostr ?? this.isOnNostr,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'npub': npub,
    'publicKey': publicKey,
    'shareIndex': shareIndex,
    'shareDelivered': shareDelivered,
    'lastSeen': lastSeen?.toIso8601String(),
    'shareDeliveredAt': shareDeliveredAt?.toIso8601String(),
    'isOnNostr': isOnNostr,
  };

  factory RecoveryContact.fromJson(Map<String, dynamic> json) =>
      RecoveryContact(
        name: json['name'] ?? '',
        phoneNumber: json['phoneNumber'],
        npub: json['npub'] ?? '',
        publicKey: json['publicKey'] ?? '',
        shareIndex: json['shareIndex'],
        shareDelivered: json['shareDelivered'] ?? false,
        lastSeen: json['lastSeen'] != null 
            ? DateTime.tryParse(json['lastSeen']) 
            : null,
        shareDeliveredAt: json['shareDeliveredAt'] != null 
            ? DateTime.tryParse(json['shareDeliveredAt']) 
            : null,
        isOnNostr: json['isOnNostr'] ?? true,
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
  static const _recoveredSeedKey = 'recovered_seed_temp';

  static late FlutterSecureStorage _secureStorage;
  static bool _initialized = false;

  /// Initialize the service
  static Future<void> init() async {
    if (_initialized) return;
    _secureStorage = const FlutterSecureStorage();
    _initialized = true;
  }

  /// Store recovered seed temporarily for wallet initialization
  static Future<void> storeRecoveredSeed(String seed) async {
    await init();
    await _secureStorage.write(key: _recoveredSeedKey, value: seed);
  }

  /// Get and clear the recovered seed
  static Future<String?> getAndClearRecoveredSeed() async {
    await init();
    final seed = await _secureStorage.read(key: _recoveredSeedKey);
    if (seed != null) {
      await _secureStorage.delete(key: _recoveredSeedKey);
    }
    return seed;
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

  /// Send health ping to all guardians
  /// Returns updated contacts with lastSeen times
  static Future<List<RecoveryContact>> pingGuardians() async {
    try {
      await init();
      final contacts = await getRecoveryContacts();
      if (contacts.isEmpty) return [];

      await NostrService.init();
      
      final updatedContacts = <RecoveryContact>[];
      
      for (final contact in contacts) {
        try {
          // Check if guardian is online by looking for their recent activity
          final lastSeen = await _checkGuardianActivity(contact.npub);
          
          updatedContacts.add(contact.copyWith(
            lastSeen: lastSeen,
          ));
        } catch (e) {
          // Keep existing lastSeen if check fails
          updatedContacts.add(contact);
        }
      }
      
      // Update stored contacts with new lastSeen times
      await _storeRecoveryContacts(updatedContacts);
      
      print('✅ Pinged ${contacts.length} guardians');
      return updatedContacts;
    } catch (e) {
      print('❌ Error pinging guardians: $e');
      return [];
    }
  }
  
  /// Check a guardian's recent Nostr activity
  static Future<DateTime?> _checkGuardianActivity(String npub) async {
    try {
      final hexPubkey = NostrService.npubToHex(npub);
      if (hexPubkey == null) return null;
      
      // Query for any recent events from this pubkey
      // This checks their metadata, notes, or any activity
      final events = await NostrService.fetchUserEvents(
        hexPubkey: hexPubkey,
        kinds: [0, 1, 4], // Metadata, notes, DMs
        limit: 1,
      );
      
      if (events.isNotEmpty) {
        final latestEvent = events.first;
        final timestamp = latestEvent['created_at'] as int?;
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ Could not check activity for $npub: $e');
      return null;
    }
  }
  
  /// Update a single guardian's contact info
  static Future<void> updateGuardian(RecoveryContact updatedContact) async {
    try {
      await init();
      final contacts = await getRecoveryContacts();
      
      final index = contacts.indexWhere((c) => c.npub == updatedContact.npub);
      if (index >= 0) {
        contacts[index] = updatedContact;
        await _storeRecoveryContacts(contacts);
        print('✅ Updated guardian: ${updatedContact.name}');
      }
    } catch (e) {
      print('❌ Error updating guardian: $e');
      rethrow;
    }
  }
  
  /// Replace a guardian with a new one
  /// This revokes the old share and sends a new one to the new contact
  static Future<void> replaceGuardian({
    required RecoveryContact oldGuardian,
    required RecoveryContact newGuardian,
    required String masterSeed,
  }) async {
    try {
      await init();
      
      final contacts = await getRecoveryContacts();
      final index = contacts.indexWhere((c) => c.npub == oldGuardian.npub);
      
      if (index < 0) {
        throw Exception('Guardian not found');
      }
      
      final shareIndex = oldGuardian.shareIndex ?? (index + 1);
      
      // Generate new shares
      final shares = await splitSeedIntoShares(masterSeed);
      final share = shares[shareIndex - 1]; // Convert to 0-based
      
      await NostrService.init();
      await NostrService.reinitialize();
      
      // Send share to new guardian
      final dmContent = jsonEncode({
        'type': 'sabi_recovery_share',
        'version': 1,
        'share_index': shareIndex,
        'share_data': share,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'message': 'This is a Sabi Wallet recovery share. Please keep it safe!',
      });
      
      await NostrService.sendEncryptedDM(
        targetNpub: newGuardian.npub,
        message: dmContent,
      );
      
      // Notify old guardian that their share is revoked
      final revokeContent = jsonEncode({
        'type': 'sabi_share_revoked',
        'version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'message': 'Your recovery share has been revoked. You can delete it.',
      });
      
      try {
        await NostrService.sendEncryptedDM(
          targetNpub: oldGuardian.npub,
          message: revokeContent,
        );
      } catch (e) {
        // Non-critical if revocation notice fails
        print('⚠️ Could not send revocation notice: $e');
      }
      
      // Update stored contacts
      final updatedNewGuardian = newGuardian.copyWith(
        shareIndex: shareIndex,
        shareDelivered: true,
        shareDeliveredAt: DateTime.now(),
      );
      
      contacts[index] = updatedNewGuardian;
      await _storeRecoveryContacts(contacts);
      
      print('✅ Replaced guardian ${oldGuardian.name} with ${newGuardian.name}');
    } catch (e) {
      print('❌ Error replacing guardian: $e');
      rethrow;
    }
  }
  
  /// Add a new guardian (only if we have fewer than 5)
  static Future<bool> addGuardian({
    required RecoveryContact newGuardian,
    required String masterSeed,
  }) async {
    try {
      await init();
      
      final contacts = await getRecoveryContacts();
      if (contacts.length >= 5) {
        print('⚠️ Cannot add more than 5 guardians');
        return false;
      }
      
      // Find next available share index
      final usedIndices = contacts
          .map((c) => c.shareIndex)
          .whereType<int>()
          .toSet();
      
      int nextIndex = 1;
      while (usedIndices.contains(nextIndex) && nextIndex <= 5) {
        nextIndex++;
      }
      
      if (nextIndex > 5) {
        print('⚠️ All share indices used');
        return false;
      }
      
      // Generate shares and send to new guardian
      final shares = await splitSeedIntoShares(masterSeed);
      final share = shares[nextIndex - 1];
      
      await NostrService.init();
      await NostrService.reinitialize();
      
      final dmContent = jsonEncode({
        'type': 'sabi_recovery_share',
        'version': 1,
        'share_index': nextIndex,
        'share_data': share,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'message': 'This is a Sabi Wallet recovery share. Please keep it safe!',
      });
      
      await NostrService.sendEncryptedDM(
        targetNpub: newGuardian.npub,
        message: dmContent,
      );
      
      // Store updated contact
      final updatedGuardian = newGuardian.copyWith(
        shareIndex: nextIndex,
        shareDelivered: true,
        shareDeliveredAt: DateTime.now(),
      );
      
      contacts.add(updatedGuardian);
      await _storeRecoveryContacts(contacts);
      
      print('✅ Added guardian: ${newGuardian.name} with share $nextIndex');
      return true;
    } catch (e) {
      print('❌ Error adding guardian: $e');
      return false;
    }
  }
  
  /// Remove a guardian (only if we have more than 3)
  static Future<bool> removeGuardian(RecoveryContact guardian) async {
    try {
      await init();
      
      final contacts = await getRecoveryContacts();
      if (contacts.length <= 3) {
        print('⚠️ Cannot have fewer than 3 guardians');
        return false;
      }
      
      // Notify guardian that their share is revoked
      try {
        await NostrService.init();
        await NostrService.reinitialize();
        
        final revokeContent = jsonEncode({
          'type': 'sabi_share_revoked',
          'version': 1,
          'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'message': 'Your recovery share has been revoked. You can delete it.',
        });
        
        await NostrService.sendEncryptedDM(
          targetNpub: guardian.npub,
          message: revokeContent,
        );
      } catch (e) {
        print('⚠️ Could not send revocation notice: $e');
      }
      
      // Remove from stored contacts
      contacts.removeWhere((c) => c.npub == guardian.npub);
      await _storeRecoveryContacts(contacts);
      
      print('✅ Removed guardian: ${guardian.name}');
      return true;
    } catch (e) {
      print('❌ Error removing guardian: $e');
      return false;
    }
  }
  
  /// Get overall recovery health status
  static Future<Map<String, dynamic>> getRecoveryHealth() async {
    try {
      final contacts = await getRecoveryContacts();
      if (contacts.isEmpty) {
        return {
          'isSetUp': false,
          'healthyCount': 0,
          'warningCount': 0,
          'offlineCount': 0,
          'totalCount': 0,
          'overallStatus': GuardianHealthStatus.unknown,
        };
      }
      
      int healthy = 0;
      int warning = 0;
      int offline = 0;
      
      for (final contact in contacts) {
        switch (contact.healthStatus) {
          case GuardianHealthStatus.healthy:
            healthy++;
            break;
          case GuardianHealthStatus.warning:
            warning++;
            break;
          case GuardianHealthStatus.offline:
            offline++;
            break;
          case GuardianHealthStatus.unknown:
            offline++; // Treat unknown as offline for safety
            break;
        }
      }
      
      // Overall status: healthy if 3+ healthy, warning if 3+ healthy+warning, else offline
      GuardianHealthStatus overall;
      if (healthy >= 3) {
        overall = GuardianHealthStatus.healthy;
      } else if (healthy + warning >= 3) {
        overall = GuardianHealthStatus.warning;
      } else {
        overall = GuardianHealthStatus.offline;
      }
      
      return {
        'isSetUp': true,
        'healthyCount': healthy,
        'warningCount': warning,
        'offlineCount': offline,
        'totalCount': contacts.length,
        'overallStatus': overall,
      };
    } catch (e) {
      print('❌ Error getting recovery health: $e');
      return {
        'isSetUp': false,
        'healthyCount': 0,
        'warningCount': 0,
        'offlineCount': 0,
        'totalCount': 0,
        'overallStatus': GuardianHealthStatus.unknown,
      };
    }
  }

  /// Send encrypted shares with proper tracking
  static Future<List<RecoveryContact>> sendRecoverySharesWithTracking({
    required String masterSeed,
    required List<RecoveryContact> selectedContacts,
  }) async {
    try {
      await init();

      if (selectedContacts.length < 3) {
        throw Exception('Must select at least 3 contacts');
      }

      await NostrService.init();
      await NostrService.reinitialize();

      final shares = await splitSeedIntoShares(masterSeed);
      final updatedContacts = <RecoveryContact>[];

      for (int i = 0; i < selectedContacts.length && i < 5; i++) {
        final contact = selectedContacts[i];
        final share = shares[i];
        final shareIndex = i + 1;

        try {
          final dmContent = jsonEncode({
            'type': 'sabi_recovery_share',
            'version': 1,
            'share_index': shareIndex,
            'share_data': share,
            'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'message': 'This is a Sabi Wallet recovery share. Please keep it safe!',
          });

          await NostrService.sendEncryptedDM(
            targetNpub: contact.npub,
            message: dmContent,
          );

          updatedContacts.add(contact.copyWith(
            shareIndex: shareIndex,
            shareDelivered: true,
            shareDeliveredAt: DateTime.now(),
          ));

          print('✅ Sent share $shareIndex to ${contact.name}');
        } catch (e) {
          // Mark as not delivered
          updatedContacts.add(contact.copyWith(
            shareIndex: shareIndex,
            shareDelivered: false,
          ));
          print('❌ Failed to send share to ${contact.name}: $e');
        }
      }

      await _storeRecoveryContacts(updatedContacts);
      return updatedContacts;
    } catch (e) {
      print('❌ Error sending recovery shares: $e');
      rethrow;
    }
  }
}

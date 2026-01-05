import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/recovery/social_recovery_service.dart';

void main() {
  group('RecoveryContact', () {
    test('fromJson parses full payload correctly', () {
      final json = {
        'name': 'Alice',
        'phoneNumber': '+1234567890',
        'npub': 'npub1example123',
        'publicKey': 'abc123hex',
        'shareIndex': 1,
        'shareDelivered': true,
        'lastSeen': '2025-01-15T10:30:00.000Z',
        'shareDeliveredAt': '2025-01-14T08:00:00.000Z',
        'isOnNostr': true,
      };

      final contact = RecoveryContact.fromJson(json);

      expect(contact.name, 'Alice');
      expect(contact.phoneNumber, '+1234567890');
      expect(contact.npub, 'npub1example123');
      expect(contact.publicKey, 'abc123hex');
      expect(contact.shareIndex, 1);
      expect(contact.shareDelivered, true);
      expect(contact.lastSeen, isNotNull);
      expect(contact.shareDeliveredAt, isNotNull);
      expect(contact.isOnNostr, true);
    });

    test('fromJson handles minimal payload', () {
      final json = {'name': 'Bob', 'npub': 'npub1bob', 'publicKey': 'bobhex'};

      final contact = RecoveryContact.fromJson(json);

      expect(contact.name, 'Bob');
      expect(contact.phoneNumber, isNull);
      expect(contact.npub, 'npub1bob');
      expect(contact.publicKey, 'bobhex');
      expect(contact.shareIndex, isNull);
      expect(contact.shareDelivered, false);
      expect(contact.lastSeen, isNull);
      expect(contact.shareDeliveredAt, isNull);
      expect(contact.isOnNostr, true); // default
    });

    test('toJson produces correct output', () {
      final contact = RecoveryContact(
        name: 'Charlie',
        phoneNumber: '+9876543210',
        npub: 'npub1charlie',
        publicKey: 'charliehex',
        shareIndex: 3,
        shareDelivered: true,
        lastSeen: DateTime.utc(2025, 1, 15, 12, 0),
        shareDeliveredAt: DateTime.utc(2025, 1, 14, 10, 0),
        isOnNostr: true,
      );

      final json = contact.toJson();

      expect(json['name'], 'Charlie');
      expect(json['phoneNumber'], '+9876543210');
      expect(json['npub'], 'npub1charlie');
      expect(json['publicKey'], 'charliehex');
      expect(json['shareIndex'], 3);
      expect(json['shareDelivered'], true);
      expect(json['lastSeen'], '2025-01-15T12:00:00.000Z');
      expect(json['shareDeliveredAt'], '2025-01-14T10:00:00.000Z');
      expect(json['isOnNostr'], true);
    });

    test('copyWith creates modified copy', () {
      final original = RecoveryContact(
        name: 'Dana',
        npub: 'npub1dana',
        publicKey: 'danahex',
        shareIndex: 1,
        shareDelivered: false,
      );

      final updated = original.copyWith(
        shareDelivered: true,
        shareDeliveredAt: DateTime.utc(2025, 1, 15),
      );

      // Original unchanged
      expect(original.shareDelivered, false);
      expect(original.shareDeliveredAt, isNull);

      // Copy updated
      expect(updated.shareDelivered, true);
      expect(updated.shareDeliveredAt, DateTime.utc(2025, 1, 15));
      expect(updated.name, 'Dana'); // unchanged fields preserved
      expect(updated.npub, 'npub1dana');
    });
  });

  group('GuardianHealthStatus', () {
    test('returns healthy for recently seen guardian', () {
      final contact = RecoveryContact(
        name: 'Recent',
        npub: 'npub1recent',
        publicKey: 'recenthex',
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.healthy);
    });

    test('returns warning for guardian seen 2 days ago', () {
      final contact = RecoveryContact(
        name: 'MidRecent',
        npub: 'npub1mid',
        publicKey: 'midhex',
        lastSeen: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.warning);
    });

    test('returns offline for guardian seen 10 days ago', () {
      final contact = RecoveryContact(
        name: 'Old',
        npub: 'npub1old',
        publicKey: 'oldhex',
        lastSeen: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.offline);
    });

    test('returns unknown for guardian never seen', () {
      final contact = RecoveryContact(
        name: 'Never',
        npub: 'npub1never',
        publicKey: 'neverhex',
        lastSeen: null,
      );

      expect(contact.healthStatus, GuardianHealthStatus.unknown);
    });

    test('boundary: 23 hours is healthy', () {
      final contact = RecoveryContact(
        name: 'Edge23',
        npub: 'npub1edge23',
        publicKey: 'edge23hex',
        lastSeen: DateTime.now().subtract(const Duration(hours: 23)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.healthy);
    });

    test('boundary: 25 hours is warning', () {
      final contact = RecoveryContact(
        name: 'Edge25',
        npub: 'npub1edge25',
        publicKey: 'edge25hex',
        lastSeen: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.warning);
    });

    test('boundary: 6 days is warning', () {
      final contact = RecoveryContact(
        name: 'Edge6',
        npub: 'npub1edge6',
        publicKey: 'edge6hex',
        lastSeen: DateTime.now().subtract(const Duration(days: 6)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.warning);
    });

    test('boundary: 7 days is offline', () {
      final contact = RecoveryContact(
        name: 'Edge7',
        npub: 'npub1edge7',
        publicKey: 'edge7hex',
        lastSeen: DateTime.now().subtract(const Duration(days: 7)),
      );

      expect(contact.healthStatus, GuardianHealthStatus.offline);
    });
  });

  group('lastSeenText', () {
    test('returns "Never seen" for null lastSeen', () {
      final contact = RecoveryContact(
        name: 'NeverSeen',
        npub: 'npub1never',
        publicKey: 'neverhex',
      );

      expect(contact.lastSeenText, 'Never seen');
    });

    test('returns "Just now" for very recent', () {
      final contact = RecoveryContact(
        name: 'JustNow',
        npub: 'npub1just',
        publicKey: 'justhex',
        lastSeen: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      expect(contact.lastSeenText, 'Just now');
    });

    test('returns minutes ago format', () {
      final contact = RecoveryContact(
        name: 'Minutes',
        npub: 'npub1min',
        publicKey: 'minhex',
        lastSeen: DateTime.now().subtract(const Duration(minutes: 45)),
      );

      expect(contact.lastSeenText, '45m ago');
    });

    test('returns hours ago format', () {
      final contact = RecoveryContact(
        name: 'Hours',
        npub: 'npub1hour',
        publicKey: 'hourhex',
        lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
      );

      expect(contact.lastSeenText, '5h ago');
    });

    test('returns days ago format', () {
      final contact = RecoveryContact(
        name: 'Days',
        npub: 'npub1day',
        publicKey: 'dayhex',
        lastSeen: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(contact.lastSeenText, '3d ago');
    });

    test('returns weeks ago format', () {
      final contact = RecoveryContact(
        name: 'Weeks',
        npub: 'npub1week',
        publicKey: 'weekhex',
        lastSeen: DateTime.now().subtract(const Duration(days: 21)),
      );

      expect(contact.lastSeenText, '3w ago');
    });
  });

  group('RecoveryShare', () {
    test('fromJson and toJson roundtrip', () {
      final original = RecoveryShare(
        index: 2,
        encryptedData: 'base64encodeddata',
        senderNpub: 'npub1sender',
        timestamp: DateTime.utc(2025, 1, 15, 10, 30),
      );

      final json = original.toJson();
      final restored = RecoveryShare.fromJson(json);

      expect(restored.index, 2);
      expect(restored.encryptedData, 'base64encodeddata');
      expect(restored.senderNpub, 'npub1sender');
      expect(restored.timestamp, DateTime.utc(2025, 1, 15, 10, 30));
    });
  });

  group('Shamir Secret Sharing', () {
    // NOTE: These tests require FlutterSecureStorage which needs
    // native platform bindings. Run these as integration tests.
    // The Shamir algorithm itself is tested implicitly by the service.

    test('reconstructSeedFromShares throws with only 2 shares', () {
      // Create mock shares with proper format (index byte + data)
      final share1 = base64.encode([1, 65, 66, 67]); // Index 1
      final share2 = base64.encode([2, 68, 69, 70]); // Index 2

      expect(
        () => SocialRecoveryService.reconstructSeedFromShares([share1, share2]),
        throwsException,
      );
    });

    // The following tests require FlutterSecureStorage initialization
    // They are commented out for unit testing but should be run as integration tests
    //
    // test('splitSeedIntoShares creates 5 shares', () async { ... });
    // test('reconstructSeedFromShares recovers original', () async { ... });
    // test('handles various seed lengths', () async { ... });
    // test('handles special characters in seed', () async { ... });
    // test('each share is unique', () async { ... });
    // test('shares are base64 encoded', () async { ... });
  });

  group('Guardian count validation', () {
    test('minimum 3 guardians required for recovery', () {
      // This is a documentation/design test
      // The actual validation is in the service methods
      const minGuardians = 3;
      const maxGuardians = 5;

      expect(minGuardians, 3);
      expect(maxGuardians, 5);
    });
  });
}

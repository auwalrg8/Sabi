import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Stub for contacts_service - plugin has compatibility issues with newer AGP versions
// TODO: Replace with maintained alternative like contacts_plus or phone_contacts
class Contact {
  String? displayName;
  Iterable<Phone>? phones;
  Iterable<Email>? emails;
}

class Phone {
  String? value;
}

class Email {
  String? value;
}

class ContactsService {
  static Future<Iterable<Contact>> getContacts() async {
    // Stub implementation - returns empty list
    // Real contact sync can be implemented later with a maintained plugin
    return [];
  }
}

class ContactInfo {
  final String displayName;
  final String identifier; // phone number or email
  final String type; // 'phone', 'email', 'lightning', 'sabi'

  ContactInfo({
    required this.displayName,
    required this.identifier,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'identifier': identifier,
    'type': type,
  };

  factory ContactInfo.fromMap(Map<String, dynamic> map) => ContactInfo(
    displayName: map['displayName'] as String,
    identifier: map['identifier'] as String,
    type: map['type'] as String,
  );
}

class ContactService {
  static const _recentContactsBox = 'recent_contacts';
  static late Box _box;

  static Future<void> init() async {
    try {
      _box = await Hive.openBox(_recentContactsBox);
      debugPrint('✅ Contact service initialized');
    } catch (e) {
      debugPrint('❌ Contact service init error: $e');
    }
  }

  /// Request contact permission
  static Future<bool> requestContactPermission() async {
    try {
      final status = await Permission.contacts.request();
      debugPrint('📱 Contact permission status: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Contact permission error: $e');
      return false;
    }
  }

  /// Import all phone contacts
  static Future<List<ContactInfo>> importPhoneContacts() async {
    try {
      final hasPermission = await requestContactPermission();
      if (!hasPermission) {
        debugPrint('⚠️ Contact permission denied');
        return [];
      }

      final Iterable<Contact> contacts = await ContactsService.getContacts();
      final List<ContactInfo> contactsList = [];

      for (final contact in contacts) {
        final name = contact.displayName ?? 'Unknown';

        // Extract phone numbers
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          for (final phone in contact.phones!) {
            final number =
                phone.value?.replaceAll(RegExp(r'[^\d+]'), '').trim();
            if (number != null && number.isNotEmpty) {
              contactsList.add(
                ContactInfo(
                  displayName: name,
                  identifier: number,
                  type: 'phone',
                ),
              );
            }
          }
        }

        // Extract emails
        if (contact.emails != null && contact.emails!.isNotEmpty) {
          for (final email in contact.emails!) {
            final value = email.value?.trim();
            if (value != null && value.isNotEmpty) {
              contactsList.add(
                ContactInfo(
                  displayName: name,
                  identifier: value,
                  type: 'email',
                ),
              );
            }
          }
        }
      }

      debugPrint('✅ Imported ${contactsList.length} contacts');
      return contactsList;
    } catch (e) {
      debugPrint('❌ Contact import error: $e');
      return [];
    }
  }

  /// Add to recent contacts after successful payment
  static Future<void> addRecentContact(ContactInfo contact) async {
    try {
      final key = '${contact.type}_${contact.identifier}';
      await _box.put(key, {
        ...contact.toMap(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('✅ Added recent contact: ${contact.displayName}');
    } catch (e) {
      debugPrint('❌ Add recent contact error: $e');
    }
  }

  /// Get recent contacts (sorted by timestamp, most recent first)
  static Future<List<ContactInfo>> getRecentContacts({int limit = 20}) async {
    try {
      final List<ContactInfo> contacts = [];

      for (final key in _box.keys) {
        final data = _box.get(key);
        contacts.add(ContactInfo.fromMap(Map<String, dynamic>.from(data)));
      }

      // Sort by timestamp (most recent first)
      contacts.sort((a, b) {
        final timeA =
            (_box.get('${a.type}_${a.identifier}') as Map)['timestamp']
                as int? ??
            0;
        final timeB =
            (_box.get('${b.type}_${b.identifier}') as Map)['timestamp']
                as int? ??
            0;
        return timeB.compareTo(timeA);
      });

      return contacts.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Get recent contacts error: $e');
      return [];
    }
  }

  /// Search contacts by name or identifier
  static Future<List<ContactInfo>> searchContacts(
    String query, {
    required List<ContactInfo> allContacts,
  }) async {
    try {
      if (query.isEmpty) return [];

      final lowerQuery = query.toLowerCase();
      return allContacts
          .where(
            (contact) =>
                contact.displayName.toLowerCase().contains(lowerQuery) ||
                contact.identifier.contains(query),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Search contacts error: $e');
      return [];
    }
  }

  /// Clear all recent contacts
  static Future<void> clearRecentContacts() async {
    try {
      await _box.clear();
      debugPrint('✅ Cleared recent contacts');
    } catch (e) {
      debugPrint('❌ Clear recent contacts error: $e');
    }
  }
}

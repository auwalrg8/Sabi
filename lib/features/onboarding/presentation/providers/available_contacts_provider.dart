// lib/features/onboarding/presentation/providers/available_contacts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/mock_contacts.dart';
import '../../domain/models/contact.dart';

part 'available_contacts_provider.g.dart';

@riverpod
List<Contact> availableContacts(Ref ref) {
  // In real app this would come from phone contacts + Nostr lookup
  return MockContacts.allContacts;
}

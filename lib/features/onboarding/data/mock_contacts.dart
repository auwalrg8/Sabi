import '../domain/models/contact.dart';

class MockContacts {
  static const List<Contact> allContacts = [
    Contact(
      name: 'Auwal Abubakar',
      phone: '+234 803 456 7890',
      isNostr: true,
    ),
    Contact(
      name: 'Mubarak Ibrahim',
      phone: '+234 803 456 7891',
      isNostr: false,
    ),
    Contact(
      name: 'Muhammad Buhari',
      phone: '+234 803 456 7892',
      isNostr: true,
    ),
    Contact(
      name: 'Musa Auwal',
      phone: '+234 803 456 7893',
      isNostr: true,
    ),
  ];

  // Add real API fetch here later
}
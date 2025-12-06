import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/contact_service.dart';

// Provider for importing phone contacts
final importContactsProvider = FutureProvider<List<ContactInfo>>((ref) async {
  return await ContactService.importPhoneContacts();
});

// Provider for recent contacts
final recentContactsProvider = FutureProvider<List<ContactInfo>>((ref) async {
  return await ContactService.getRecentContacts();
});

// Provider for contact search
final contactSearchProvider =
    StateNotifierProvider<ContactSearchNotifier, ContactSearchState>((ref) {
      return ContactSearchNotifier();
    });

class ContactSearchState {
  final String query;
  final List<ContactInfo> results;
  final bool isLoading;

  const ContactSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
  });

  ContactSearchState copyWith({
    String? query,
    List<ContactInfo>? results,
    bool? isLoading,
  }) {
    return ContactSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ContactSearchNotifier extends StateNotifier<ContactSearchState> {
  ContactSearchNotifier() : super(const ContactSearchState());

  Future<void> search(String query, List<ContactInfo> allContacts) async {
    state = state.copyWith(query: query, isLoading: true);

    final results = await ContactService.searchContacts(
      query,
      allContacts: allContacts,
    );

    state = state.copyWith(results: results, isLoading: false);
  }

  void clear() {
    state = const ContactSearchState();
  }
}

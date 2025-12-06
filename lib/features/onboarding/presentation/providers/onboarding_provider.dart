import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/contact.dart';

part 'onboarding_provider.g.dart';

enum OnboardingPath { createNew, recoverWithGuys, importNostr }

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  OnboardingState build() => OnboardingState();

  void setPath(OnboardingPath path) => state = state.copyWith(path: path);
  void setBackupMethod(BackupMethod method) => state = state.copyWith(backupMethod: method);

  void toggleContact(Contact contact) {
    final newSet = Set<Contact>.from(state.selectedContacts);
    if (newSet.contains(contact)) {
      newSet.remove(contact);
    } else if (newSet.length < 3) {
      newSet.add(contact);
    }
    state = state.copyWith(selectedContacts: newSet);
  }

  void clear() => state = OnboardingState();
}

enum BackupMethod { socialRecovery, seedPhrase, skip }

class OnboardingState {
  final OnboardingPath? path;
  final BackupMethod? backupMethod;
  final Set<Contact> selectedContacts;

  OnboardingState({
    this.path,
    this.backupMethod,
    this.selectedContacts = const {},
  });

  OnboardingState copyWith({
    OnboardingPath? path,
    BackupMethod? backupMethod,
    Set<Contact>? selectedContacts,
  }) {
    return OnboardingState(
      path: path ?? this.path,
      backupMethod: backupMethod ?? this.backupMethod,
      selectedContacts: selectedContacts ?? this.selectedContacts,
    );
  }

  bool get hasThreeContacts => selectedContacts.length == 3;
  List<Contact> get contactList => selectedContacts.toList();
}
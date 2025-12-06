import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sabi_wallet/features/profile/domain/models/profile.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Profile build() {
    return const Profile(
      name: 'Ade Ogunleye',
      username: '@sabi_ade',
      initial: 'A',
    );
  }

  void updateProfile(Profile profile) {
    state = profile;
  }
}

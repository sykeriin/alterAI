import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_provider.dart';
import '../../profile/domain/user_profile.dart';

/// True when the user has finished onboarding with a display name.
bool isProfileReady(UserProfile? profile) =>
    profile != null &&
    profile.onboardingDone &&
    profile.displayName.trim().isNotEmpty;

final profileReadyProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).asData?.value;
  return isProfileReady(profile);
});

import 'package:alter/src/data/gateway/gateway_profile_context.dart';
import 'package:alter/src/features/profile/domain/user_profile.dart';

class GatewayProfileContext {
  const GatewayProfileContext._();

  static bool _ready(UserProfile? profile) =>
      profile != null && profile.displayName.trim().isNotEmpty;

  static Map<String, Object> userProfile(UserProfile? profile) {
    if (!_ready(profile)) return const <String, Object>{};
    return <String, Object>{
      'name': profile!.displayName,
      if (profile.role.isNotEmpty) 'current_role': profile.role,
      if (profile.careerStage.isNotEmpty) 'career_stage': profile.careerStage,
      if (profile.industry.isNotEmpty) 'industry': profile.industry,
    };
  }

  static List<String> skills(UserProfile? profile) =>
      profile?.skills.isNotEmpty == true ? profile!.skills : const <String>[];

  static List<String> goals(UserProfile? profile) =>
      profile?.goals.isNotEmpty == true ? profile!.goals : const <String>[];

  static List<String> interests(UserProfile? profile) =>
      profile?.interests.isNotEmpty == true
          ? profile!.interests
          : const <String>[];
}

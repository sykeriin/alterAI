import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_state.dart';
import '../../../core/config/alter_supabase_config.dart';
import '../../../data/local/dao_providers.dart';
import '../../../services/openai_service.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/supabase_auth_service.dart';
import '../../auth/data/supabase_profile_repository.dart';
import '../../voice/application/voice_io_preference.dart';
import '../domain/user_profile.dart';

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    ref.watch(isDbUnlockedProvider);
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return null;

    final profile = await ref.read(profileDaoProvider).getByUserId(userId);
    await _migrateLegacyKeys(userId, profile);

    if (profile == null) {
      final empty = UserProfile(
        id: userId,
        displayName: '',
        role: '',
        careerStage: '',
        industry: '',
        bio: '',
        skills: const [],
        goals: const [],
        interests: const [],
        languages: const ['English'],
        location: '',
        availability: '',
        openaiKey: '',
        sarvamKey: '',
        onboardingDone: false,
      );
      await ref.read(profileDaoProvider).upsert(empty);
      return empty;
    }

    if (profile.languages.isNotEmpty) {
      ref
          .read(alterAppControllerProvider.notifier)
          .setLanguage(profile.languages.first);
    }

    return profile;
  }

  Future<void> _migrateLegacyKeys(String userId, UserProfile? profile) async {
    const sarvamPref = 'alter_sarvam_api_key';
    final prefs = await SharedPreferences.getInstance();
    final legacySarvam = prefs.getString(sarvamPref);
    if (legacySarvam == null || legacySarvam.isEmpty) return;

    final current = profile ??
        UserProfile(
          id: userId,
          displayName: '',
          role: '',
          careerStage: '',
          industry: '',
          bio: '',
          skills: const [],
          goals: const [],
          interests: const [],
          languages: const ['English'],
          location: '',
          availability: '',
          openaiKey: '',
          sarvamKey: '',
          onboardingDone: false,
        );

    if (current.sarvamKey.isEmpty) {
      await ref
          .read(profileDaoProvider)
          .upsert(current.copyWith(sarvamKey: legacySarvam));
      await prefs.remove(sarvamPref);
    }
  }

  Future<void> save(UserProfile profile) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();
    final saved = profile.id == userId
        ? profile
        : UserProfile(
            id: userId,
            displayName: profile.displayName,
            role: profile.role,
            careerStage: profile.careerStage,
            industry: profile.industry,
            bio: profile.bio,
            skills: profile.skills,
            goals: profile.goals,
            interests: profile.interests,
            languages: profile.languages,
            location: profile.location,
            availability: profile.availability,
            openaiKey: profile.openaiKey,
            sarvamKey: profile.sarvamKey,
            onboardingDone: profile.onboardingDone,
          );
    await ref.read(profileDaoProvider).upsert(saved);
    state = AsyncValue.data(saved);
    await _syncToSupabase(saved);

    if (profile.languages.isNotEmpty) {
      ref
          .read(alterAppControllerProvider.notifier)
          .setLanguage(profile.languages.first);
    }
  }

  Future<void> _syncToSupabase(UserProfile profile) async {
    if (!AlterSupabaseConfig.isConfigured) return;
    if (!ref.read(supabaseAuthProvider).isSignedIn) return;
    try {
      await SupabaseProfileRepository(Supabase.instance.client)
          .upsertProfile(profile);
    } catch (e) {
      if (kDebugMode) debugPrint('Supabase profile sync skipped: $e');
    }
  }
}

final openAIServiceProvider = Provider<OpenAIService?>((ref) {
  if (!ref.watch(isDbUnlockedProvider)) return null;
  if (!ref.watch(cloudAiEnabledProvider)) return null;

  final profile = ref.watch(userProfileProvider).asData?.value;
  final byok =
      profile?.openaiKey.isNotEmpty == true ? profile!.openaiKey : null;

  final service = OpenAIService(byokKey: byok);
  ref.onDispose(service.dispose);
  return service;
});

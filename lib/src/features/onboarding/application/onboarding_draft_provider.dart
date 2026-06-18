import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../profile/application/profile_provider.dart';
import '../../profile/domain/user_profile.dart';

/// Shared onboarding form state across Languages → About You screens.
class OnboardingDraft {
  const OnboardingDraft({
    this.languages = const {'English'},
    this.displayName = '',
    this.role = 'Student',
    this.education = '',
    this.skills = const [],
    this.location = '',
    this.availability = '',
    this.goal = '',
    this.bio = '',
    this.interests = const [],
  });

  final Set<String> languages;
  final String displayName;
  final String role;
  final String education;
  final List<String> skills;
  final String location;
  final String availability;
  final String goal;
  final String bio;
  final List<String> interests;

  OnboardingDraft copyWith({
    Set<String>? languages,
    String? displayName,
    String? role,
    String? education,
    List<String>? skills,
    String? location,
    String? availability,
    String? goal,
    String? bio,
    List<String>? interests,
  }) {
    return OnboardingDraft(
      languages: languages ?? this.languages,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      education: education ?? this.education,
      skills: skills ?? this.skills,
      location: location ?? this.location,
      availability: availability ?? this.availability,
      goal: goal ?? this.goal,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
    );
  }

  factory OnboardingDraft.fromProfile(UserProfile profile) {
    return OnboardingDraft(
      languages: profile.languages.isNotEmpty
          ? profile.languages.toSet()
          : {'English'},
      displayName: profile.displayName,
      role: profile.role.isNotEmpty ? profile.role : 'Student',
      education: profile.industry,
      skills: List<String>.from(profile.skills),
      location: profile.location,
      availability: profile.availability,
      goal: profile.goals.isNotEmpty ? profile.goals.first : '',
      bio: profile.bio,
      interests: List<String>.from(profile.interests),
    );
  }

  UserProfile toProfile({
    required String id,
    required String openaiKey,
    required bool onboardingDone,
  }) {
    final goals = goal.trim().isEmpty ? <String>[] : [goal.trim()];
    final bioText = bio.trim().isNotEmpty
        ? bio.trim()
        : (goal.trim().isNotEmpty ? goal.trim() : '');
    return UserProfile(
      id: id,
      displayName: displayName.trim().isNotEmpty ? displayName.trim() : 'Alter user',
      role: role,
      careerStage: role,
      industry: education.trim(),
      bio: bioText,
      skills: skills,
      goals: goals,
      interests: interests,
      languages: languages.toList(),
      location: location.trim(),
      availability: availability.trim(),
      openaiKey: openaiKey,
      sarvamKey: '',
      onboardingDone: onboardingDone,
    );
  }
}

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    ref.watch(authStateStreamProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    if (profile != null) {
      return OnboardingDraft.fromProfile(profile);
    }
    return const OnboardingDraft();
  }

  void update(OnboardingDraft draft) => state = draft;

  void setLanguages(Set<String> languages) {
    state = state.copyWith(languages: languages);
  }

  void clear() {
    state = const OnboardingDraft();
  }
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
  OnboardingDraftNotifier.new,
);

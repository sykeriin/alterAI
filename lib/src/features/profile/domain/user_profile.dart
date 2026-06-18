class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.careerStage,
    required this.industry,
    required this.bio,
    required this.skills,
    required this.goals,
    required this.interests,
    required this.languages,
    required this.location,
    required this.availability,
    required this.openaiKey,
    required this.sarvamKey,
    required this.onboardingDone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      careerStage: json['career_stage'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? const [],
      goals: (json['goals'] as List<dynamic>?)?.cast<String>() ?? const [],
      interests:
          (json['interests'] as List<dynamic>?)?.cast<String>() ?? const [],
      languages:
          (json['languages'] as List<dynamic>?)?.cast<String>() ?? const ['English'],
      location: json['location'] as String? ?? '',
      availability: json['availability'] as String? ?? '',
      openaiKey: json['openai_key'] as String? ?? '',
      sarvamKey: json['sarvam_key'] as String? ?? '',
      onboardingDone: json['onboarding_done'] as bool? ?? false,
    );
  }

  final String id;
  final String displayName;
  final String role;
  final String careerStage;
  final String industry;
  final String bio;
  final List<String> skills;
  final List<String> goals;
  final List<String> interests;
  final List<String> languages;
  final String location;
  final String availability;
  final String openaiKey;
  final String sarvamKey;
  final bool onboardingDone;

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'role': role,
        'career_stage': careerStage,
        'industry': industry,
        'bio': bio,
        'skills': skills,
        'goals': goals,
        'interests': interests,
        'languages': languages,
        'location': location,
        'availability': availability,
        'openai_key': openaiKey,
        'sarvam_key': sarvamKey,
        'onboarding_done': onboardingDone,
      };

  UserProfile copyWith({
    String? displayName,
    String? role,
    String? careerStage,
    String? industry,
    String? bio,
    List<String>? skills,
    List<String>? goals,
    List<String>? interests,
    List<String>? languages,
    String? location,
    String? availability,
    String? openaiKey,
    String? sarvamKey,
    bool? onboardingDone,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      careerStage: careerStage ?? this.careerStage,
      industry: industry ?? this.industry,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      goals: goals ?? this.goals,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      location: location ?? this.location,
      availability: availability ?? this.availability,
      openaiKey: openaiKey ?? this.openaiKey,
      sarvamKey: sarvamKey ?? this.sarvamKey,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}

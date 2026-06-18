class NfcProfile {
  const NfcProfile({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.portfolioUrl,
    required this.resumeUrl,
    required this.linkedinUrl,
    required this.skills,
    required this.interests,
    required this.goals,
    required this.lookingFor,
    required this.startupStage,
    required this.preferredHackathons,
    required this.location,
    required this.updatedAt,
  });

  factory NfcProfile.fromJson(Map<String, dynamic> json) {
    final payload = json['profile'];
    final profile = payload is Map<String, dynamic> ? payload : json;
    return NfcProfile(
      userId: _string(profile['userId']),
      displayName: _string(profile['displayName']),
      role: _string(profile['role']),
      portfolioUrl: _string(profile['portfolioUrl']),
      resumeUrl: _string(profile['resumeUrl']),
      linkedinUrl: _string(profile['linkedinUrl']),
      skills: _stringList(profile['skills']),
      interests: _stringList(profile['interests']),
      goals: _stringList(profile['goals']),
      lookingFor: _stringList(profile['lookingFor']),
      startupStage: _string(profile['startupStage']),
      preferredHackathons: _stringList(profile['preferredHackathons']),
      location: _string(profile['location']),
      updatedAt:
          DateTime.tryParse(_string(profile['updatedAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String userId;
  final String displayName;
  final String role;
  final String portfolioUrl;
  final String resumeUrl;
  final String linkedinUrl;
  final List<String> skills;
  final List<String> interests;
  final List<String> goals;
  final List<String> lookingFor;
  final String startupStage;
  final List<String> preferredHackathons;
  final String location;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'role': role,
      'portfolioUrl': portfolioUrl,
      'resumeUrl': resumeUrl,
      'linkedinUrl': linkedinUrl,
      'skills': skills,
      'interests': interests,
      'goals': goals,
      'lookingFor': lookingFor,
      'startupStage': startupStage,
      'preferredHackathons': preferredHackathons,
      'location': location,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toExchangePayload() {
    return {'schema': alterNfcProfileSchema, 'profile': toJson()};
  }

  List<NfcProfileLink> get links {
    return [
      NfcProfileLink(label: 'Portfolio', url: portfolioUrl),
      NfcProfileLink(label: 'Resume', url: resumeUrl),
      NfcProfileLink(label: 'LinkedIn', url: linkedinUrl),
    ].where((link) => link.url.trim().isNotEmpty).toList(growable: false);
  }
}

class NfcProfileLink {
  const NfcProfileLink({required this.label, required this.url});

  final String label;
  final String url;
}

const alterNfcProfileSchema = 'alter.nfc.profile.v1';

String _string(Object? value) => value?.toString().trim() ?? '';

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(value);
  return text.isEmpty ? const [] : [text];
}

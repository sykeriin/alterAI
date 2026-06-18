import 'dart:math' as math;

import 'nfc_match.dart';
import 'nfc_profile.dart';

class NfcMatchEngine {
  const NfcMatchEngine();

  NfcExchangeResult evaluate({
    required NfcProfile localProfile,
    required NfcProfile peerProfile,
  }) {
    final sharedSkills = _overlap(localProfile.skills, peerProfile.skills);
    final sharedInterests = _overlap(
      localProfile.interests,
      peerProfile.interests,
    );
    final lookingForOverlap = _overlap(
      localProfile.lookingFor,
      peerProfile.lookingFor,
    );
    final skills = _jaccard(localProfile.skills, peerProfile.skills);
    final interests = _jaccard(localProfile.interests, peerProfile.interests);
    final goals = _jaccard(localProfile.goals, peerProfile.goals);
    final intent = _jaccard(localProfile.lookingFor, peerProfile.lookingFor);
    final location = _sameLocation(localProfile.location, peerProfile.location);
    final role = _roleAffinity(localProfile.role, peerProfile.role);

    final compatibilityScore = _score(
      skills * 0.34 +
          interests * 0.26 +
          goals * 0.14 +
          intent * 0.12 +
          location * 0.04 +
          role * 0.10,
    );

    final startupMatch = _startupSignal(
      localProfile,
      peerProfile,
      skills,
      interests,
      role,
      lookingForOverlap,
    );
    final hackathonMatch = _hackathonSignal(
      localProfile,
      peerProfile,
      skills,
      interests,
      sharedSkills,
    );
    final cofounderMatch = _cofounderSignal(
      localProfile,
      peerProfile,
      sharedSkills,
      sharedInterests,
    );

    return NfcExchangeResult(
      localProfile: localProfile,
      peerProfile: peerProfile,
      compatibilityScore: compatibilityScore,
      startupMatch: startupMatch,
      hackathonMatch: hackathonMatch,
      cofounderMatch: cofounderMatch,
      sharedSkills: sharedSkills,
      sharedInterests: sharedInterests,
      recommendedActions: _recommendedActions(
        compatibilityScore,
        startupMatch,
        hackathonMatch,
        cofounderMatch,
      ),
      createdAt: DateTime.now(),
    );
  }

  NfcMatchSignal _startupSignal(
    NfcProfile local,
    NfcProfile peer,
    double skills,
    double interests,
    double roleAffinity,
    List<String> lookingForOverlap,
  ) {
    final stage =
        _normalize(local.startupStage) == _normalize(peer.startupStage)
        ? 1.0
        : 0.35;
    final founderIntent = _containsAny(
      [...local.lookingFor, ...peer.lookingFor, ...local.goals, ...peer.goals],
      const ['startup', 'founder', 'pilot', 'investor', 'customer'],
    );
    final score = _score(
      skills * 0.26 +
          interests * 0.24 +
          roleAffinity * 0.20 +
          stage * 0.14 +
          (founderIntent ? 1 : 0) * 0.16,
    );
    return NfcMatchSignal(
      title: 'Startup Match',
      score: score,
      reasons: [
        if (roleAffinity > 0.7) 'Roles create a useful startup path.',
        if (stage > 0.9) 'Startup stage is aligned.',
        if (lookingForOverlap.isNotEmpty)
          'Both want ${lookingForOverlap.take(2).join(', ')}.',
        if (founderIntent) 'Exchange has founder or pilot intent.',
      ],
    );
  }

  NfcMatchSignal _hackathonSignal(
    NfcProfile local,
    NfcProfile peer,
    double skills,
    double interests,
    List<String> sharedSkills,
  ) {
    final eventOverlap = _jaccard(
      local.preferredHackathons,
      peer.preferredHackathons,
    );
    final buildIntent = _containsAny(
      [
        ...local.lookingFor,
        ...peer.lookingFor,
        ...local.interests,
        ...peer.interests,
      ],
      const ['hackathon', 'build', 'prototype', 'open source', 'artifact'],
    );
    final score = _score(
      skills * 0.34 +
          interests * 0.20 +
          eventOverlap * 0.24 +
          (buildIntent ? 1 : 0) * 0.22,
    );
    return NfcMatchSignal(
      title: 'Hackathon Match',
      score: score,
      reasons: [
        if (sharedSkills.isNotEmpty)
          'Shared build skills: ${sharedSkills.take(3).join(', ')}.',
        if (eventOverlap > 0) 'Hackathon preferences overlap.',
        if (buildIntent) 'Both profiles signal build momentum.',
      ],
    );
  }

  NfcMatchSignal _cofounderSignal(
    NfcProfile local,
    NfcProfile peer,
    List<String> sharedSkills,
    List<String> sharedInterests,
  ) {
    final unionSkillDepth = _normalizedUnion(
      local.skills,
      peer.skills,
      cap: 14,
    );
    final complementarySkills = math.max(
      0,
      1 - _jaccard(local.skills, peer.skills),
    );
    final sharedInterestScore = sharedInterests.isEmpty
        ? 0.28
        : math.min(1, sharedInterests.length / 4);
    final cofounderIntent = _containsAny(
      [...local.lookingFor, ...peer.lookingFor, ...local.goals, ...peer.goals],
      const ['co-founder', 'cofounder', 'founder', 'team', 'startup'],
    );
    final score = _score(
      unionSkillDepth * 0.30 +
          complementarySkills * 0.22 +
          sharedInterestScore * 0.20 +
          (cofounderIntent ? 1 : 0) * 0.28,
    );
    return NfcMatchSignal(
      title: 'Co-founder Match',
      score: score,
      reasons: [
        if (sharedSkills.isNotEmpty)
          'Shared operating language: ${sharedSkills.take(2).join(', ')}.',
        if (complementarySkills > 0.5) 'Skill sets are complementary.',
        if (sharedInterests.isNotEmpty)
          'Interest overlap: ${sharedInterests.take(2).join(', ')}.',
        if (cofounderIntent) 'Profiles show team-building intent.',
      ],
    );
  }

  List<String> _recommendedActions(
    double compatibility,
    NfcMatchSignal startup,
    NfcMatchSignal hackathon,
    NfcMatchSignal cofounder,
  ) {
    final best = [startup, hackathon, cofounder]
      ..sort((a, b) => b.score.compareTo(a.score));
    return [
      if (compatibility >= 72) 'Save to Social Graph as high-signal.',
      'Open with ${best.first.title.toLowerCase()} context.',
      if (startup.score >= 70) 'Route to Opportunity Radar for warm follow-up.',
      if (hackathon.score >= 70) 'Create a build sprint memory.',
      if (cofounder.score >= 70)
        'Ask Clone Council for a collaboration thesis.',
    ];
  }
}

double _score(double value) => (value.clamp(0, 1) * 100).roundToDouble();

double _jaccard(List<String> left, List<String> right) {
  final a = left.map(_normalize).where((item) => item.isNotEmpty).toSet();
  final b = right.map(_normalize).where((item) => item.isNotEmpty).toSet();
  if (a.isEmpty && b.isEmpty) {
    return 0.0;
  }
  return a.intersection(b).length / a.union(b).length;
}

List<String> _overlap(List<String> left, List<String> right) {
  final rightTerms = right.map(_normalize).toSet();
  return left
      .where((item) => rightTerms.contains(_normalize(item)))
      .toSet()
      .toList(growable: false);
}

double _sameLocation(String left, String right) {
  if (left.trim().isEmpty || right.trim().isEmpty) {
    return 0.0;
  }
  return _normalize(left) == _normalize(right) ? 1.0 : 0.0;
}

double _roleAffinity(String left, String right) {
  final a = _normalize(left);
  final b = _normalize(right);
  if (a == b && a.contains('founder')) {
    return 0.82;
  }
  const highAffinity = {
    'founder:investor',
    'founder:recruiter',
    'founder:student',
    'founder:professor',
    'student:recruiter',
    'student:professor',
    'founder:founder',
  };
  return highAffinity.contains('$a:$b') || highAffinity.contains('$b:$a')
      ? 1.0
      : 0.48;
}

double _normalizedUnion(
  List<String> left,
  List<String> right, {
  required int cap,
}) {
  final union = {
    ...left.map(_normalize).where((item) => item.isNotEmpty),
    ...right.map(_normalize).where((item) => item.isNotEmpty),
  };
  return math.min(1, union.length / cap);
}

bool _containsAny(List<String> values, List<String> needles) {
  final text = values.map(_normalize).join(' ');
  return needles.any((needle) => text.contains(_normalize(needle)));
}

String _normalize(String value) =>
    value.toLowerCase().trim().replaceAll('-', ' ');

import 'nfc_profile.dart';

class NfcExchangeResult {
  const NfcExchangeResult({
    required this.localProfile,
    required this.peerProfile,
    required this.compatibilityScore,
    required this.startupMatch,
    required this.hackathonMatch,
    required this.cofounderMatch,
    required this.sharedSkills,
    required this.sharedInterests,
    required this.recommendedActions,
    required this.createdAt,
  });

  final NfcProfile localProfile;
  final NfcProfile peerProfile;
  final double compatibilityScore;
  final NfcMatchSignal startupMatch;
  final NfcMatchSignal hackathonMatch;
  final NfcMatchSignal cofounderMatch;
  final List<String> sharedSkills;
  final List<String> sharedInterests;
  final List<String> recommendedActions;
  final DateTime createdAt;

  List<NfcMatchSignal> get signals {
    return [startupMatch, hackathonMatch, cofounderMatch];
  }
}

class NfcMatchSignal {
  const NfcMatchSignal({
    required this.title,
    required this.score,
    required this.reasons,
  });

  final String title;
  final double score;
  final List<String> reasons;

  String get percentage => '${score.round()}%';
}

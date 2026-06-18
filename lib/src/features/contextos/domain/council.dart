import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';

/// The five inner voices ALTER convenes for important decisions.
enum CouncilAgent {
  practical(
    'practical',
    'Practical Me',
    'gets it done sensibly',
    AlterPalette.iris,
    Icons.construction,
  ),
  risk(
    'risk',
    'Risk Me',
    'guards the downside',
    AlterPalette.danger,
    Icons.gpp_maybe_outlined,
  ),
  future(
    'future',
    'Future Me',
    'thinks in years',
    AlterPalette.cyan,
    Icons.timeline,
  ),
  skeptic(
    'skeptic',
    'Skeptic Me',
    'distrusts the obvious',
    AlterPalette.amber,
    Icons.psychology_alt_outlined,
  ),
  action(
    'action',
    'Action Me',
    'turns it into moves',
    AlterPalette.mint,
    Icons.bolt,
  );

  const CouncilAgent(this.id, this.label, this.tagline, this.color, this.icon);

  final String id;
  final String label;
  final String tagline;
  final Color color;
  final IconData icon;

  static CouncilAgent fromId(String v) => CouncilAgent.values.firstWhere(
    (a) => a.id == v.toLowerCase(),
    orElse: () => CouncilAgent.practical,
  );
}

class CouncilVoice {
  const CouncilVoice({
    required this.agent,
    required this.stance,
    required this.take,
    required this.confidence,
  });

  factory CouncilVoice.fromJson(Map<String, dynamic> j) => CouncilVoice(
    agent: CouncilAgent.fromId((j['agent'] ?? 'practical').toString()),
    stance: (j['stance'] ?? '').toString(),
    take: (j['take'] ?? '').toString(),
    confidence: j['confidence'] is num
        ? (j['confidence'] as num).toDouble()
        : 0.6,
  );

  final CouncilAgent agent;
  final String stance;
  final String take;
  final double confidence;
}

class CouncilResult {
  const CouncilResult({
    required this.voices,
    required this.consensus,
    required this.recommendation,
    required this.dissent,
    required this.cloudUsed,
  });

  factory CouncilResult.fromJson(
    Map<String, dynamic> j, {
    required bool cloud,
  }) {
    final voices = (j['voices'] is List)
        ? (j['voices'] as List)
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => CouncilVoice.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <CouncilVoice>[];
    return CouncilResult(
      voices: voices,
      consensus: (j['consensus'] ?? '').toString(),
      recommendation: (j['recommendation'] ?? '').toString(),
      dissent: (j['dissent'] ?? '').toString(),
      cloudUsed: cloud,
    );
  }

  final List<CouncilVoice> voices;
  final String consensus;
  final String recommendation;
  final String dissent;
  final bool cloudUsed;
}

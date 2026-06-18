/// Five persona perspectives for important decisions (Stage 6).
enum AlterPersona {
  presentSelf('Present Self', 'Immediate constraints and current reality'),
  futureSelf('Future Self', 'Long-term outcomes and regret'),
  realist('Realist', 'Risks, effort, and failure cases'),
  strategist('Strategist', 'Opportunities, leverage, and next moves'),
  valuesSelf('Values Self', 'Alignment with identity and priorities');

  const AlterPersona(this.label, this.responsibility);

  final String label;
  final String responsibility;

  String systemPrompt(String identityBlock, String memoryBlock) {
    return 'You are ALTER\'s ${label} persona. $responsibility. '
        'Respond from this perspective only. Base reasoning on evidence — '
        'do not invent facts.\n'
        'Identity evidence:\n$identityBlock\n'
        'Relevant memories:\n$memoryBlock';
  }
}

class PersonaOpinion {
  const PersonaOpinion({
    required this.persona,
    required this.summary,
    required this.assumptions,
    required this.risks,
    required this.recommendation,
  });

  final AlterPersona persona;
  final String summary;
  final List<String> assumptions;
  final List<String> risks;
  final String recommendation;
}

class CouncilDeliberation {
  const CouncilDeliberation({
    required this.question,
    required this.opinions,
    required this.disagreements,
    required this.experiment,
  });

  final String question;
  final List<PersonaOpinion> opinions;
  final List<String> disagreements;
  final Map<String, String> experiment;
}

/// Sequential five-persona evaluation — not five models running continuously.
class FivePersonaCouncil {
  const FivePersonaCouncil();

  static bool shouldDeliberate(String transcript) {
    final lower = transcript.toLowerCase();
    return RegExp(
      r'\b(should i|worth it|better to|switch|quit|accept|invest|which option|decide)\b',
    ).hasMatch(lower);
  }

  List<Map<String, String>> buildSequentialMessages({
    required String question,
    required String identityBlock,
    required String memoryBlock,
  }) {
    return [
      for (final persona in AlterPersona.values)
        {
          'role': 'system',
          'content': persona.systemPrompt(identityBlock, memoryBlock),
        },
      {'role': 'user', 'content': question},
    ];
  }
}

import 'package:flutter/material.dart';

class AssistantBrief {
  const AssistantBrief({
    required this.greeting,
    required this.focus,
    required this.nextAction,
    required this.signals,
  });

  static const empty = AssistantBrief(
    greeting: '',
    focus: '',
    nextAction: '',
    signals: [],
  );

  final String greeting;
  final String focus;
  final String nextAction;
  final List<String> signals;
}

class CloneAgent {
  const CloneAgent({
    required this.name,
    required this.role,
    required this.state,
    required this.confidence,
    required this.accent,
    required this.summary,
  });

  final String name;
  final String role;
  final String state;
  final double confidence;
  final Color accent;
  final String summary;
}

class FutureScenario {
  const FutureScenario({
    required this.title,
    required this.horizon,
    required this.probability,
    required this.upside,
    required this.risk,
    required this.levers,
  });

  final String title;
  final String horizon;
  final double probability;
  final String upside;
  final String risk;
  final List<String> levers;
}

class OpportunitySignal {
  const OpportunitySignal({
    required this.title,
    required this.category,
    required this.score,
    required this.source,
    required this.window,
    required this.evidence,
  });

  final String title;
  final String category;
  final double score;
  final String source;
  final String window;
  final String evidence;
}

class SocialContact {
  const SocialContact({
    required this.name,
    required this.context,
    required this.strength,
    required this.tags,
  });

  final String name;
  final String context;
  final double strength;
  final List<String> tags;
}

class ReputationEvent {
  const ReputationEvent({
    required this.title,
    required this.delta,
    required this.description,
    required this.timestamp,
  });

  final String title;
  final int delta;
  final String description;
  final String timestamp;
}

class LensInsight {
  const LensInsight({
    required this.title,
    required this.confidence,
    required this.description,
    required this.actions,
  });

  final String title;
  final double confidence;
  final String description;
  final List<String> actions;
}

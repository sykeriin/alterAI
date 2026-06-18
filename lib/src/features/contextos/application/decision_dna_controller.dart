import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/alter_palette.dart';
import 'openclaw_adapter.dart';

/// The eight outcomes the OutcomeLearningEngine asks for after an action.
enum OutcomeKind {
  correctWarning('correct_warning', 'Correct warning', true),
  verifiedSafe('verified_safe', 'Verified safe', true),
  worked('worked', 'Worked', true),
  falseAlarm('false_alarm', 'False alarm', false),
  delayed('delayed', 'Delayed', false),
  failed('failed', 'Failed', false),
  regretted('regretted', 'Regretted', false),
  needsStrongerWarning(
    'needs_stronger_warning',
    'Needs stronger warning',
    false,
  );

  const OutcomeKind(this.id, this.label, this.positive);
  final String id;
  final String label;
  final bool positive;

  Color get color => positive ? AlterPalette.mint : AlterPalette.amber;
}

class DnaPattern {
  const DnaPattern({
    required this.pattern,
    required this.evidence,
    required this.weight,
  });

  final String pattern;
  final String evidence;
  final double weight; // 0..1
}

class DecisionDna {
  const DecisionDna({
    required this.patterns,
    required this.outcomeCounts,
    required this.trustScore,
    required this.totalOutcomes,
  });

  final List<DnaPattern> patterns;
  final Map<OutcomeKind, int> outcomeCounts;
  final double trustScore; // 0..1 follow-through quality
  final int totalOutcomes;

  static const empty = DecisionDna(
    patterns: [],
    outcomeCounts: {},
    trustScore: 0.5,
    totalOutcomes: 0,
  );
}

final decisionDnaProvider =
    AsyncNotifierProvider<DecisionDnaController, DecisionDna>(
      DecisionDnaController.new,
    );

class DecisionDnaController extends AsyncNotifier<DecisionDna> {
  @override
  Future<DecisionDna> build() => _load();

  /// OutcomeLearningEngine entry point — record how an action turned out, then
  /// recompute Decision DNA.
  Future<void> recordOutcome(
    ClawAction action,
    OutcomeKind outcome, {
    String note = '',
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('action_outcomes').insert({
          'user_id': userId,
          if (action.dbId != null) 'action_id': action.dbId,
          'outcome': outcome.id,
          'note': note.isEmpty ? action.title : note,
        });
        await Supabase.instance.client.from('audit_events').insert({
          'user_id': userId,
          'kind': 'outcome',
          'detail': '${action.title} → ${outcome.label}',
          'edge_state': 'edge',
        });
      } catch (_) {}
    }
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _load());
  }

  Future<DecisionDna> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    List<Map<String, dynamic>> rows = const [];
    if (userId != null) {
      try {
        final res = await Supabase.instance.client
            .from('action_outcomes')
            .select('outcome, note, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(100);
        rows = (res as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return _compute(rows);
  }

  DecisionDna _compute(List<Map<String, dynamic>> rows) {
    final counts = <OutcomeKind, int>{};
    for (final r in rows) {
      final kind = OutcomeKind.values.firstWhere(
        (k) => k.id == r['outcome']?.toString(),
        orElse: () => OutcomeKind.worked,
      );
      counts[kind] = (counts[kind] ?? 0) + 1;
    }

    final total = rows.length;
    final positives = counts.entries
        .where((e) => e.key.positive)
        .fold<int>(0, (s, e) => s + e.value);
    final trust = total == 0
        ? 0.5
        : (positives / total).clamp(0.0, 1.0).toDouble();

    final patterns = <DnaPattern>[];
    if (total == 0) {
      patterns.add(
        const DnaPattern(
          pattern: 'Learning starts now',
          evidence:
              'Confirm a few actions and log how they turned out — ALTER '
              'builds your Decision DNA from real outcomes.',
          weight: 0.3,
        ),
      );
    } else {
      final verified = counts[OutcomeKind.verifiedSafe] ?? 0;
      final correct = counts[OutcomeKind.correctWarning] ?? 0;
      final falseAlarms = counts[OutcomeKind.falseAlarm] ?? 0;
      final regretted = counts[OutcomeKind.regretted] ?? 0;
      final stronger = counts[OutcomeKind.needsStrongerWarning] ?? 0;

      if (verified + correct > 0) {
        patterns.add(
          DnaPattern(
            pattern: 'You verify before you act',
            evidence:
                '${verified + correct} of $total flagged moments were checked and '
                'handled safely.',
            weight: ((verified + correct) / total).clamp(0.2, 1).toDouble(),
          ),
        );
      }
      if (falseAlarms > 0) {
        patterns.add(
          DnaPattern(
            pattern: 'ALTER is over-warning you',
            evidence:
                '$falseAlarms false alarm(s) — tune sensitivity down for '
                'sources you trust.',
            weight: (falseAlarms / total).clamp(0.2, 1).toDouble(),
          ),
        );
      }
      if (stronger > 0 || regretted > 0) {
        patterns.add(
          DnaPattern(
            pattern: 'Some risks slipped through',
            evidence:
                '${stronger + regretted} moment(s) needed a stronger warning '
                '— ALTER will escalate similar ones faster.',
            weight: ((stronger + regretted) / total).clamp(0.2, 1).toDouble(),
          ),
        );
      }
      patterns.add(
        DnaPattern(
          pattern: trust >= 0.7
              ? 'High follow-through operator'
              : trust >= 0.45
              ? 'Building follow-through'
              : 'Follow-through needs work',
          evidence:
              '${(trust * 100).round()}% of logged outcomes were positive across '
              '$total actions.',
          weight: trust,
        ),
      );
    }

    return DecisionDna(
      patterns: patterns,
      outcomeCounts: counts,
      trustScore: trust,
      totalOutcomes: total,
    );
  }
}

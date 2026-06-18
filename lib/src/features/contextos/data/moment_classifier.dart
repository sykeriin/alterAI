import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contextos_models.dart';
import '../domain/moment.dart';

final momentClassifierProvider = Provider<MomentClassifier>(
  (ref) => const MomentClassifier(),
);

/// Decides what KIND of moment this is and which mode should own it. This is
/// the ContextOS router — the reason ALTER reacts like a system layer instead
/// of answering everything in one generic chat thread.
class MomentClassifier {
  const MomentClassifier();

  static final _decision = RegExp(
    r'\b(should i|worth it|better to|switch|quit|resign|move to|relocat|accept the offer|take the (job|role)|invest|buy a|which (one|option))\b',
    caseSensitive: false,
  );
  static final _day = RegExp(
    r'\b(traffic|delay|eta|cab|airport|boarding|commute|meeting at|calendar|schedule|running late|flight)\b',
    caseSensitive: false,
  );
  static final _reminder = RegExp(
    r'\b(remind|due|renew|bill|deadline|expires on|appointment|pay by)\b',
    caseSensitive: false,
  );

  MomentCategory classify(
    Moment moment,
    EdgeTriage triage,
    ContextExtraction ctx,
  ) {
    final lower = moment.rawContent.toLowerCase();

    final highRisk =
        triage.coarseVerdict == RiskVerdict.dangerous ||
        triage.coarseVerdict == RiskVerdict.needsVerification ||
        ctx.risks.values.any((v) => v >= 0.8);

    // Risk dominates everything — a scam dressed as a question is still a scam.
    if (highRisk) return MomentCategory.riskyAction;

    if (_day.hasMatch(lower)) return MomentCategory.dayPressurePoint;

    if (_decision.hasMatch(lower)) return MomentCategory.futureDecision;

    if (_reminder.hasMatch(lower)) return MomentCategory.reminderActionItem;

    // A question with mild risk or an ask, but no clear scam → hidden decision.
    final hasAsk = ctx.requestedAction.isNotEmpty || lower.contains('?');
    if (triage.coarseVerdict == RiskVerdict.caution ||
        (hasAsk && ctx.topRisk > 0.2)) {
      return MomentCategory.hiddenDecision;
    }

    if (moment.rawContent.trim().length < 16 && ctx.topRisk < 0.1) {
      return MomentCategory.ignore;
    }

    return MomentCategory.safeInfo;
  }
}

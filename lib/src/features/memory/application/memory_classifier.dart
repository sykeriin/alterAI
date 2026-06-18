import '../../contextos/domain/moment.dart';
import '../domain/memory_item.dart';

/// Local lightweight classifier: relevance, sensitivity, intent, retention.
class MemoryClassifierService {
  const MemoryClassifierService();

  static final _otp = RegExp(r'\b\d{4,8}\b.*(?:otp|code|pin|verify)', caseSensitive: false);
  static final _commitment = RegExp(
    r'\b(due|deadline|by friday|tomorrow|meeting|appointment|remind)\b',
    caseSensitive: false,
  );
  static final _preference = RegExp(
    r'\b(prefer|always|never|usually|routine|habit)\b',
    caseSensitive: false,
  );
  static final _relationship = RegExp(
    r'\b(mom|dad|manager|team|friend|contact|call|text)\b',
    caseSensitive: false,
  );
  static final _goal = RegExp(
    r'\b(goal|want to|plan to|aspire|become|ship|build)\b',
    caseSensitive: false,
  );

  MemoryClassification classify({
    required String rawContent,
    String provenance = 'signal',
    MomentCategory? momentCategory,
  }) {
    final lower = rawContent.trim().toLowerCase();
    if (lower.isEmpty || lower.length < 8) {
      return const MemoryClassification(
        relevant: false,
        sensitive: false,
        requiresAction: false,
        shouldRemember: false,
        retention: MemoryRetention.immediateDelete,
        kind: MemoryKind.observation,
        sensitivity: MemorySensitivity.normal,
        confidence: 0.1,
      );
    }

    if (_otp.hasMatch(lower)) {
      return const MemoryClassification(
        relevant: true,
        sensitive: true,
        requiresAction: false,
        shouldRemember: false,
        retention: MemoryRetention.immediateDelete,
        kind: MemoryKind.observation,
        sensitivity: MemorySensitivity.sensitive,
        confidence: 0.95,
      );
    }

    final isRisky = momentCategory == MomentCategory.riskyAction;
    final isDecision = momentCategory == MomentCategory.futureDecision ||
        momentCategory == MomentCategory.hiddenDecision;
    final isReminder = momentCategory == MomentCategory.reminderActionItem;

    MemoryKind kind = MemoryKind.observation;
    if (_preference.hasMatch(lower)) kind = MemoryKind.preference;
    if (_relationship.hasMatch(lower)) kind = MemoryKind.relationship;
    if (_commitment.hasMatch(lower) || isReminder) kind = MemoryKind.commitment;
    if (_goal.hasMatch(lower)) kind = MemoryKind.goal;
    if (isDecision) kind = MemoryKind.decision;

    final requiresAction = isRisky ||
        isReminder ||
        momentCategory == MomentCategory.dayPressurePoint;
    final relevant = !isRisky || requiresAction;
    final sensitive = isRisky || lower.contains('password') || lower.contains('bank');

    MemoryRetention retention = MemoryRetention.ephemeral;
    if (kind == MemoryKind.preference || kind == MemoryKind.goal) {
      retention = MemoryRetention.durable;
    }
    if (kind == MemoryKind.commitment) {
      retention = MemoryRetention.ephemeral;
    }

    return MemoryClassification(
      relevant: relevant,
      sensitive: sensitive,
      requiresAction: requiresAction,
      shouldRemember: relevant && retention != MemoryRetention.immediateDelete,
      retention: retention,
      kind: kind,
      sensitivity: sensitive
          ? MemorySensitivity.sensitive
          : MemorySensitivity.normal,
      confidence: isDecision ? 0.72 : 0.58,
    );
  }
}

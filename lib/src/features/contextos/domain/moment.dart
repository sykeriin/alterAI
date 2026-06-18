import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';
import 'contextos_models.dart';

/// How sensitive a captured moment is — drives the privacy path.
enum PrivacyLevel {
  normal('Normal'),
  sensitive('Sensitive'),
  private('Private (local only)');

  const PrivacyLevel(this.label);
  final String label;
}

/// A single phone "moment" intercepted from any surface. This is the unit that
/// flows through the whole ContextOS pipeline.
class Moment {
  const Moment({
    required this.id,
    required this.sourceSurface,
    required this.sourceType,
    required this.rawContent,
    required this.timestamp,
    required this.deviceContext,
    required this.privacyLevel,
  });

  final String id;
  final MomentSource sourceSurface;
  final String
  sourceType; // text | sms | chat | link | image_text | transcript | day
  final String rawContent;
  final DateTime timestamp;
  final Map<String, String> deviceContext;
  final PrivacyLevel privacyLevel;

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Moment copyWith({PrivacyLevel? privacyLevel}) => Moment(
    id: id,
    sourceSurface: sourceSurface,
    sourceType: sourceType,
    rawContent: rawContent,
    timestamp: timestamp,
    deviceContext: deviceContext,
    privacyLevel: privacyLevel ?? this.privacyLevel,
  );
}

/// What kind of moment this is — decides which ContextOS mode handles it.
enum MomentCategory {
  safeInfo(
    'Safe info',
    'lifeshield',
    AlterPalette.mint,
    Icons.check_circle_outline,
  ),
  riskyAction(
    'Risky action',
    'lifeshield',
    AlterPalette.danger,
    Icons.gpp_maybe_outlined,
  ),
  hiddenDecision(
    'Hidden decision',
    'lifeshield',
    AlterPalette.iris,
    Icons.visibility_outlined,
  ),
  dayPressurePoint(
    'Day pressure point',
    'daytwin',
    AlterPalette.cyan,
    Icons.schedule,
  ),
  futureDecision(
    'Future decision',
    'futuretwin',
    AlterPalette.violet,
    Icons.alt_route,
  ),
  reminderActionItem(
    'Action item',
    'reminder',
    AlterPalette.amber,
    Icons.task_alt,
  ),
  ignore(
    'No action needed',
    'none',
    AlterPalette.slate,
    Icons.do_not_disturb_on_outlined,
  );

  const MomentCategory(this.label, this.mode, this.color, this.icon);

  final String label;
  final String mode; // lifeshield | daytwin | futuretwin | reminder | none
  final Color color;
  final IconData icon;

  bool get handledByLifeShield => mode == 'lifeshield';
  bool get isRoutedElsewhere => mode == 'daytwin' || mode == 'futuretwin';
}

/// Structured understanding of a moment (ContextEngine output). Scores 0..1.
class ContextExtraction {
  const ContextExtraction({
    required this.entities,
    required this.requestedAction,
    required this.deadline,
    required this.risks,
    required this.sensitiveDataRequest,
    required this.missingInfo,
    required this.confidence,
    required this.cloudEnriched,
  });

  /// Risk dimensions keyed by label, each 0..1.
  static const riskKeys = <String>[
    'Money',
    'Identity',
    'Permission',
    'Link / domain',
    'QR / payment',
    'Location',
    'Urgency',
  ];

  factory ContextExtraction.empty() => const ContextExtraction(
    entities: [],
    requestedAction: '',
    deadline: '',
    risks: {},
    sensitiveDataRequest: false,
    missingInfo: [],
    confidence: 0,
    cloudEnriched: false,
  );

  final List<String> entities;
  final String requestedAction;
  final String deadline;
  final Map<String, double> risks;
  final bool sensitiveDataRequest;
  final List<String> missingInfo;
  final double confidence;
  final bool cloudEnriched;

  double get topRisk =>
      risks.values.isEmpty ? 0 : risks.values.reduce((a, b) => a > b ? a : b);

  List<MapEntry<String, double>> get activeRisks {
    final list = risks.entries.where((e) => e.value > 0.05).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  ContextExtraction mergeCloud(Map<String, dynamic> json) {
    List<String> strs(Object? v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const [];
    double dbl(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

    final cloudRisks = <String, double>{...risks};
    if (json['risks'] is Map) {
      (json['risks'] as Map).forEach((k, v) {
        final key = riskKeys.firstWhere(
          (rk) => rk.toLowerCase().startsWith(k.toString().toLowerCase()),
          orElse: () => '',
        );
        if (key.isNotEmpty) {
          cloudRisks[key] = (dbl(v)).clamp(0, 1).toDouble();
        }
      });
    }

    final mergedEntities = {...entities, ...strs(json['entities'])}.toList();

    return ContextExtraction(
      entities: mergedEntities,
      requestedAction: (json['requested_action'] ?? requestedAction).toString(),
      deadline: (json['deadline'] ?? deadline).toString(),
      risks: cloudRisks,
      sensitiveDataRequest:
          json['sensitive_data_request'] == true || sensitiveDataRequest,
      missingInfo: strs(json['missing_info']).isEmpty
          ? missingInfo
          : strs(json['missing_info']),
      confidence: dbl(json['confidence']) > 0
          ? dbl(json['confidence'])
          : confidence,
      cloudEnriched: true,
    );
  }
}

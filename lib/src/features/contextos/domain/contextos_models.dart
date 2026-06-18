import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';

/// The phone surface a moment was captured from.
enum MomentSource {
  notification('notification', 'Notification', Icons.notifications_outlined),
  shareSheet('share_sheet', 'Share sheet', Icons.ios_share),
  camera('camera', 'Camera', Icons.camera_alt_outlined),
  mic('mic', 'Voice', Icons.mic_none),
  screenshot('screenshot', 'Screenshot', Icons.screenshot_monitor_outlined),
  sms('sms', 'SMS', Icons.sms_outlined),
  whatsapp('whatsapp', 'WhatsApp', Icons.chat_bubble_outline),
  social('social', 'Social', Icons.groups_outlined),
  notes('notes', 'Notes', Icons.sticky_note_2_outlined),
  photos('photos', 'Photos', Icons.photo_library_outlined),
  contacts('contacts', 'Contacts', Icons.contacts_outlined),
  calendar('calendar', 'Calendar', Icons.event_available_outlined),
  email('email', 'Email', Icons.alternate_email),
  browser('browser', 'Browser', Icons.travel_explore_outlined),
  location('location', 'Location', Icons.location_on_outlined),
  files('files', 'Files', Icons.folder_outlined),
  qr('qr', 'QR / Payment', Icons.qr_code_scanner),
  call('call', 'Call', Icons.call_outlined),
  install('install', 'Install', Icons.download_outlined),
  payment('payment', 'Payment', Icons.payments_outlined),
  manual('manual', 'Manual', Icons.edit_outlined);

  const MomentSource(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static MomentSource fromId(String id) => MomentSource.values.firstWhere(
    (s) => s.id == id,
    orElse: () => MomentSource.manual,
  );
}

/// LifeShield risk verdict. Colors follow the ContextOS system palette:
/// green = safe, amber = caution, red = dangerous, blue = needs-verification.
enum RiskVerdict {
  safe('safe', 'Safe', AlterPalette.mint),
  caution('caution', 'Caution', AlterPalette.amber),
  dangerous('dangerous', 'Dangerous', AlterPalette.danger),
  needsVerification(
    'needs_verification',
    'Needs verification',
    AlterPalette.cyan,
  );

  const RiskVerdict(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;

  static RiskVerdict fromId(String id) => RiskVerdict.values.firstWhere(
    (v) => v.id == id,
    orElse: () => RiskVerdict.needsVerification,
  );
}

/// Where the reasoning happened — shown to the user at all times.
enum EdgeState {
  edge('edge', 'On-device', AlterPalette.mint),
  private('private', 'Private (local only)', AlterPalette.iris),
  cloud('cloud', 'Cloud reasoning', AlterPalette.cyan);

  const EdgeState(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;
}

/// A safe action LifeShield proposes. Confirmation/irreversibility gate OpenClaw.
class SafeAction {
  const SafeAction({
    required this.type,
    required this.title,
    required this.detail,
    this.requiresConfirmation = true,
    this.irreversible = false,
  });

  factory SafeAction.fromJson(Map<String, dynamic> json) => SafeAction(
    type: (json['type'] ?? 'safe_ignore').toString(),
    title: (json['title'] ?? '').toString(),
    detail: (json['detail'] ?? '').toString(),
    requiresConfirmation: json['requires_confirmation'] == true,
    irreversible: json['irreversible'] == true,
  );

  final String type;
  final String title;
  final String detail;
  final bool requiresConfirmation;
  final bool irreversible;
}

/// The full Proof Mode + verdict + actions for one moment.
/// This is the combined output of ContextEngine + ProofEngine + ActionEngine.
class MomentAnalysis {
  const MomentAnalysis({
    required this.verdict,
    required this.riskScore,
    required this.headline,
    required this.whyItMatters,
    required this.facts,
    required this.redFlags,
    required this.assumptions,
    required this.missingInfo,
    required this.whatCouldMakeWrong,
    required this.verificationSteps,
    required this.confidence,
    required this.edgeSummary,
    required this.actions,
    required this.cloudUsed,
    required this.edgeState,
    required this.redactedFields,
  });

  factory MomentAnalysis.fromJson(
    Map<String, dynamic> json, {
    required String edgeSummary,
    required bool cloudUsed,
    required EdgeState edgeState,
    required List<String> redactedFields,
  }) {
    List<String> strs(Object? v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const [];
    double dbl(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

    return MomentAnalysis(
      verdict: RiskVerdict.fromId((json['verdict'] ?? '').toString()),
      riskScore: dbl(json['risk_score']).clamp(0, 1),
      headline: (json['headline'] ?? 'Moment analyzed').toString(),
      whyItMatters: (json['why_it_matters'] ?? '').toString(),
      facts: strs(json['facts']),
      redFlags: strs(json['red_flags']),
      assumptions: strs(json['assumptions']),
      missingInfo: strs(json['missing_info']),
      whatCouldMakeWrong: (json['what_could_make_wrong'] ?? '').toString(),
      verificationSteps: strs(json['verification_steps']),
      confidence: dbl(json['confidence']).clamp(0, 1),
      edgeSummary: edgeSummary,
      actions: (json['actions'] is List)
          ? (json['actions'] as List)
                .whereType<Map>()
                .map((e) => SafeAction.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      cloudUsed: cloudUsed,
      edgeState: edgeState,
      redactedFields: redactedFields,
    );
  }

  final RiskVerdict verdict;
  final double riskScore;
  final String headline;
  final String whyItMatters;
  final List<String> facts;
  final List<String> redFlags;
  final List<String> assumptions;
  final List<String> missingInfo;
  final String whatCouldMakeWrong;
  final List<String> verificationSteps;
  final double confidence;
  final String edgeSummary;
  final List<SafeAction> actions;
  final bool cloudUsed;
  final EdgeState edgeState;
  final List<String> redactedFields;
}

/// Result of the edge (Gemma) first pass — runs fully on-device.
class EdgeTriage {
  const EdgeTriage({
    required this.redactedText,
    required this.redactedFields,
    required this.coarseVerdict,
    required this.signals,
    required this.shouldEscalate,
    required this.summary,
  });

  final String redactedText;
  final List<String> redactedFields;
  final RiskVerdict coarseVerdict;
  final List<String> signals;
  final bool shouldEscalate;
  final String summary;
}

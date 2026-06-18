import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';

enum TwinAccessLevel {
  off('off', 'Off', 0),
  metadata('metadata', 'Meta', 1),
  redacted('redacted', 'Redact', 2),
  localFull('local_full', 'Local', 3);

  const TwinAccessLevel(this.id, this.label, this.weight);

  final String id;
  final String label;
  final int weight;

  static TwinAccessLevel fromId(String id) => TwinAccessLevel.values.firstWhere(
    (level) => level.id == id,
    orElse: () => TwinAccessLevel.off,
  );

  String get scopeLabel => switch (this) {
    TwinAccessLevel.off => 'No access',
    TwinAccessLevel.metadata => 'Names, dates, counts only',
    TwinAccessLevel.redacted => 'Redacted memories',
    TwinAccessLevel.localFull => 'Full local index',
  };

  String get cloudBoundary => switch (this) {
    TwinAccessLevel.off => 'Nothing leaves the phone.',
    TwinAccessLevel.metadata => 'Only metadata can be summarized.',
    TwinAccessLevel.redacted => 'Cloud receives redacted summaries only.',
    TwinAccessLevel.localFull => 'Raw data stays on-device.',
  };
}

enum TwinAutonomyLevel {
  observe('observe', 'Observe', 'Read context and flag important moments.', 0),
  recommend('recommend', 'Recommend', 'Suggest decisions in your voice.', 1),
  draft('draft', 'Draft', 'Prepare replies, plans, and app actions.', 2),
  confirmAct(
    'confirm_act',
    'Confirm Act',
    'Execute through OpenClaw after approval.',
    3,
  );

  const TwinAutonomyLevel(this.id, this.label, this.detail, this.weight);

  final String id;
  final String label;
  final String detail;
  final int weight;

  static TwinAutonomyLevel fromId(String id) =>
      TwinAutonomyLevel.values.firstWhere(
        (level) => level.id == id,
        orElse: () => TwinAutonomyLevel.recommend,
      );
}

enum DigitalTwinSource {
  moments(
    'moments',
    'Moments',
    'Shared messages, links, QR prompts, payments, screenshots.',
    Icons.auto_awesome_motion_outlined,
    2,
    TwinAccessLevel.redacted,
    TwinAccessLevel.redacted,
  ),
  notifications(
    'notifications',
    'Notifications',
    'Live app notifications across messaging and social apps.',
    Icons.notifications_outlined,
    4,
    TwinAccessLevel.redacted,
    TwinAccessLevel.redacted,
  ),
  sms(
    'sms',
    'SMS',
    'Texts, OTP patterns, delivery updates, payment requests.',
    Icons.sms_outlined,
    5,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  whatsapp(
    'whatsapp',
    'WhatsApp',
    'Chats through notifications, share intents, or official exports.',
    Icons.chat_bubble_outline,
    5,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  calls(
    'calls',
    'Calls',
    'Call logs, missed calls, follow-up context.',
    Icons.call_outlined,
    4,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  email(
    'email',
    'Email',
    'Gmail, Outlook, receipts, travel, work threads.',
    Icons.alternate_email,
    4,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  social(
    'social',
    'Social',
    'Instagram, X, LinkedIn, Messenger, Telegram notifications.',
    Icons.groups_outlined,
    4,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  notes(
    'notes',
    'Notes',
    'Your notes, ideas, lists, journal fragments.',
    Icons.sticky_note_2_outlined,
    5,
    TwinAccessLevel.off,
    TwinAccessLevel.localFull,
  ),
  photos(
    'photos',
    'Photos',
    'Camera roll memories, documents, screenshots, places.',
    Icons.photo_library_outlined,
    5,
    TwinAccessLevel.off,
    TwinAccessLevel.localFull,
  ),
  contacts(
    'contacts',
    'Contacts',
    'People, numbers, relationship names, trusted circles.',
    Icons.contacts_outlined,
    3,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  calendar(
    'calendar',
    'Calendar',
    'Plans, meetings, routines, deadlines.',
    Icons.event_available_outlined,
    3,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  files(
    'files',
    'Files',
    'Documents, downloads, PDFs, project artifacts.',
    Icons.folder_outlined,
    4,
    TwinAccessLevel.off,
    TwinAccessLevel.localFull,
  ),
  browser(
    'browser',
    'Browser',
    'Searches, links, reading history, intent signals.',
    Icons.travel_explore_outlined,
    3,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  ),
  location(
    'location',
    'Location',
    'Places, commute patterns, arrival and departure context.',
    Icons.location_on_outlined,
    5,
    TwinAccessLevel.off,
    TwinAccessLevel.redacted,
  );

  const DigitalTwinSource(
    this.id,
    this.label,
    this.description,
    this.icon,
    this.sensitivity,
    this.defaultAccess,
    this.completeTwinAccess,
  );

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int sensitivity;
  final TwinAccessLevel defaultAccess;
  final TwinAccessLevel completeTwinAccess;

  static DigitalTwinSource fromId(String id) =>
      DigitalTwinSource.values.firstWhere(
        (source) => source.id == id,
        orElse: () => DigitalTwinSource.moments,
      );

  Color get color => switch (sensitivity) {
    >= 5 => AlterPalette.danger,
    4 => AlterPalette.amber,
    3 => AlterPalette.cyan,
    _ => AlterPalette.mint,
  };
}

class TwinSourceConsent {
  const TwinSourceConsent({
    required this.source,
    required this.accessLevel,
    this.connected = false,
  });

  factory TwinSourceConsent.fromJson(Map<String, dynamic> json) {
    final source = DigitalTwinSource.fromId(
      (json['source_key'] ?? json['source'] ?? '').toString(),
    );
    final accessLevel = TwinAccessLevel.fromId(
      (json['access_level'] ?? '').toString(),
    );
    return TwinSourceConsent(
      source: source,
      accessLevel: accessLevel,
      connected:
          json['connected'] == true || accessLevel != TwinAccessLevel.off,
    );
  }

  final DigitalTwinSource source;
  final TwinAccessLevel accessLevel;
  final bool connected;

  bool get isActive => accessLevel != TwinAccessLevel.off;

  double get coverageWeight {
    final accessWeight = switch (accessLevel) {
      TwinAccessLevel.off => 0.0,
      TwinAccessLevel.metadata => 0.3,
      TwinAccessLevel.redacted => 0.72,
      TwinAccessLevel.localFull => 1.0,
    };
    return source.sensitivity * accessWeight;
  }

  TwinSourceConsent copyWith({TwinAccessLevel? accessLevel, bool? connected}) =>
      TwinSourceConsent(
        source: source,
        accessLevel: accessLevel ?? this.accessLevel,
        connected: connected ?? this.connected,
      );
}

class DigitalTwinState {
  DigitalTwinState({
    required Map<DigitalTwinSource, TwinSourceConsent> sources,
    required this.autonomyLevel,
    required this.updatedAt,
  }) : sources = Map.unmodifiable(sources);

  factory DigitalTwinState.defaults() {
    final sources = <DigitalTwinSource, TwinSourceConsent>{
      for (final source in DigitalTwinSource.values)
        source: TwinSourceConsent(
          source: source,
          accessLevel: source.defaultAccess,
          connected: source.defaultAccess != TwinAccessLevel.off,
        ),
    };
    return DigitalTwinState(
      sources: sources,
      autonomyLevel: TwinAutonomyLevel.recommend,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final Map<DigitalTwinSource, TwinSourceConsent> sources;
  final TwinAutonomyLevel autonomyLevel;
  final DateTime updatedAt;

  TwinSourceConsent consentFor(DigitalTwinSource source) =>
      sources[source] ??
      TwinSourceConsent(source: source, accessLevel: source.defaultAccess);

  int get activeSourceCount =>
      sources.values.where((source) => source.isActive).length;

  int get localFullCount => sources.values
      .where((source) => source.accessLevel == TwinAccessLevel.localFull)
      .length;

  double get readinessScore {
    final max = DigitalTwinSource.values.fold<double>(
      0,
      (sum, source) => sum + source.sensitivity,
    );
    if (max == 0) return 0;
    final score = sources.values.fold<double>(
      0,
      (sum, source) => sum + source.coverageWeight,
    );
    return (score / max).clamp(0.0, 1.0).toDouble();
  }

  double get personalityDepth {
    final chatWeight = [
      DigitalTwinSource.notifications,
      DigitalTwinSource.sms,
      DigitalTwinSource.whatsapp,
      DigitalTwinSource.email,
      DigitalTwinSource.social,
    ].fold<double>(0, (sum, source) => sum + consentFor(source).coverageWeight);
    final maxChatWeight = [
      DigitalTwinSource.notifications,
      DigitalTwinSource.sms,
      DigitalTwinSource.whatsapp,
      DigitalTwinSource.email,
      DigitalTwinSource.social,
    ].fold<double>(0, (sum, source) => sum + source.sensitivity);
    if (maxChatWeight == 0) return 0;
    return (chatWeight / maxChatWeight).clamp(0.0, 1.0).toDouble();
  }

  String get maturityLabel {
    final pct = readinessScore;
    if (pct >= 0.82) return 'High fidelity';
    if (pct >= 0.58) return 'Useful twin';
    if (pct >= 0.28) return 'Learning';
    return 'Seed';
  }

  List<String> get hardGuardrails => const [
    'No silent sends, payments, installs, deletes, or account changes.',
    'Full chat, photo, note, and file indexes stay local by default.',
    'OpenClaw must explain and confirm every high-impact action.',
  ];

  DigitalTwinState copyWith({
    Map<DigitalTwinSource, TwinSourceConsent>? sources,
    TwinAutonomyLevel? autonomyLevel,
    DateTime? updatedAt,
  }) => DigitalTwinState(
    sources: sources ?? this.sources,
    autonomyLevel: autonomyLevel ?? this.autonomyLevel,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DigitalTwinState withSource(
    DigitalTwinSource source,
    TwinAccessLevel accessLevel,
  ) {
    final next = Map<DigitalTwinSource, TwinSourceConsent>.from(sources);
    next[source] = consentFor(source).copyWith(
      accessLevel: accessLevel,
      connected: accessLevel != TwinAccessLevel.off,
    );
    return copyWith(sources: next, updatedAt: DateTime.now());
  }

  DigitalTwinState stageCompleteTwin() {
    return copyWith(
      sources: {
        for (final source in DigitalTwinSource.values)
          source: TwinSourceConsent(
            source: source,
            accessLevel: source.completeTwinAccess,
            connected: source.completeTwinAccess != TwinAccessLevel.off,
          ),
      },
      autonomyLevel: TwinAutonomyLevel.draft,
      updatedAt: DateTime.now(),
    );
  }
}

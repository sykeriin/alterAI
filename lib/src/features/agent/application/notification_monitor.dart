import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../../contextos/application/gemma_model_manager.dart';
import '../../contextos/domain/contextos_models.dart';
import 'persistent_intelligence_store.dart';

/// One notification ALTER watched and triaged ON-DEVICE. Only the redacted
/// excerpt + verdict are kept; nothing is sent to the cloud here.
class LiveMoment {
  const LiveMoment({
    required this.app,
    required this.packageName,
    required this.notificationId,
    required this.title,
    required this.excerpt,
    required this.verdict,
    required this.at,
    required this.canReply,
    this.event,
  });

  final String app;
  final String packageName;
  final int notificationId;
  final String title;
  final String excerpt; // redacted on-device
  final RiskVerdict verdict;
  final DateTime at;
  final bool canReply;
  final ServiceNotificationEvent? event;
}

class MonitorState {
  const MonitorState({
    this.supported = true,
    this.granted = false,
    this.enabled = false,
    this.moments = const [],
    this.error = '',
  });

  final bool supported;
  final bool granted;
  final bool enabled;
  final List<LiveMoment> moments;
  final String error;

  int get flaggedCount =>
      moments.where((m) => m.verdict != RiskVerdict.safe).length;

  MonitorState copyWith({
    bool? supported,
    bool? granted,
    bool? enabled,
    List<LiveMoment>? moments,
    String? error,
  }) => MonitorState(
    supported: supported ?? this.supported,
    granted: granted ?? this.granted,
    enabled: enabled ?? this.enabled,
    moments: moments ?? this.moments,
    error: error ?? this.error,
  );
}

const _appNames = <String, String>{
  'com.whatsapp': 'WhatsApp',
  'com.whatsapp.w4b': 'WhatsApp Business',
  'com.google.android.apps.messaging': 'Messages',
  'com.android.messaging': 'Messages',
  'org.telegram.messenger': 'Telegram',
  'com.instagram.android': 'Instagram',
  'com.facebook.orca': 'Messenger',
  'com.facebook.katana': 'Facebook',
  'com.google.android.gm': 'Gmail',
  'com.snapchat.android': 'Snapchat',
  'com.linkedin.android': 'LinkedIn',
  'com.twitter.android': 'X',
  'com.microsoft.office.outlook': 'Outlook',
};

final notificationMonitorProvider =
    NotifierProvider<NotificationMonitor, MonitorState>(
      NotificationMonitor.new,
    );

class NotificationMonitor extends Notifier<MonitorState> {
  StreamSubscription<ServiceNotificationEvent>? _sub;

  @override
  MonitorState build() {
    if (kIsWeb) {
      return const MonitorState(supported: false);
    }
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_refreshPermission);
    return const MonitorState();
  }

  Future<void> _refreshPermission() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      state = state.copyWith(granted: granted);
      if (granted) _subscribe();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Asks the user (in system settings) to grant notification access, then
  /// starts on-device monitoring.
  Future<void> enable() async {
    if (!state.supported) return;
    try {
      final granted = await NotificationListenerService.requestPermission();
      state = state.copyWith(granted: granted);
      if (granted) _subscribe();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void disable() {
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(enabled: false);
  }

  void clear() => state = state.copyWith(moments: const []);

  Future<String> replyToLatest({
    required String text,
    String packageName = '',
  }) async {
    LiveMoment? target;
    for (final moment in state.moments) {
      final packageMatches =
          packageName.trim().isEmpty ||
          moment.packageName == packageName ||
          moment.app.toLowerCase() == packageName.toLowerCase();
      if (moment.canReply && moment.event != null && packageMatches) {
        target = moment;
        break;
      }
    }
    if (target == null) {
      return 'No replyable notification is available right now.';
    }
    try {
      final ok = await target.event!.sendReply(text);
      return ok
          ? 'Replied to ${target.app} notification.'
          : 'Android did not accept the notification reply.';
    } catch (error) {
      return 'Could not reply to notification: $error';
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = NotificationListenerService.notificationsStream.listen(_onEvent);
    state = state.copyWith(enabled: true, error: '');
  }

  Future<void> _onEvent(ServiceNotificationEvent e) async {
    if (e.hasRemoved == true) return;
    final raw = '${e.title ?? ''}: ${e.content ?? ''}'.trim();
    if (raw.length < 4) return;

    // ON-DEVICE triage only — redact + classify. No network here.
    final engine = ref.read(localGemmaEngineProvider);
    final triage = await engine.analyzeAsync(raw);

    final moment = LiveMoment(
      app: _appNames[e.packageName] ?? (e.packageName ?? 'App'),
      packageName: e.packageName ?? '',
      notificationId: e.id ?? -1,
      title: e.title ?? '',
      excerpt: triage.redactedText.length > 160
          ? '${triage.redactedText.substring(0, 160)}…'
          : triage.redactedText,
      verdict: triage.coarseVerdict,
      at: DateTime.now(),
      canReply: e.canReply == true,
      event: e,
    );

    final next = [moment, ...state.moments];
    state = state.copyWith(
      moments: next.length > 60 ? next.sublist(0, 60) : next,
    );
    await ref
        .read(persistentIntelligenceStoreProvider.notifier)
        .addMemory(
          source: 'notification',
          title: '${moment.app}: ${moment.title}',
          summary: moment.excerpt,
          metadata: {
            'package_name': moment.packageName,
            'notification_id': moment.notificationId,
            'can_reply': moment.canReply,
            'verdict': moment.verdict.name,
          },
        );
  }
}

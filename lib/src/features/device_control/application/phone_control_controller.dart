import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../../data/local/contextos_dao.dart';
import '../../../data/local/dao_providers.dart';
import '../data/device_control_bridge.dart';
import '../domain/phone_action_policy.dart';
import '../domain/screen_understanding.dart';

final deviceControlBridgeProvider = Provider<DeviceControlBridge>((ref) {
  return DeviceControlBridge();
});

final phoneControlControllerProvider =
    NotifierProvider<PhoneControlController, PhoneControlState>(
      PhoneControlController.new,
    );

class PhoneControlController extends Notifier<PhoneControlState> {
  @override
  PhoneControlState build() {
    Future.microtask(refresh);
    return const PhoneControlState();
  }

  Future<void> refresh() async {
    final enabled = await ref
        .read(deviceControlBridgeProvider)
        .isAccessibilityEnabled();
    final adminStatus = await ref
        .read(deviceControlBridgeProvider)
        .getDeviceAdminStatus();
    state = state.copyWith(
      accessibilityEnabled: enabled,
      deviceAdminStatus: adminStatus,
      error: '',
    );
  }

  Future<String> openAccessibilitySettings() async {
    final policy = PhoneActionPolicy.classify(
      kind: 'open_settings',
      target: 'accessibility_settings',
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openAccessibilitySettings();
    _audit(
      kind: 'permission',
      target: 'accessibility_settings',
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> openApp({String appName = '', String packageName = ''}) async {
    final target = packageName.isNotEmpty ? packageName : appName;
    final policy = PhoneActionPolicy.classify(kind: 'open_app', target: target);
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openApp(appName: appName, packageName: packageName);
    _audit(
      kind: 'open_app',
      target: target,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> openSettings(String screen) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'open_settings',
      target: screen,
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openSettings(screen);
    _audit(
      kind: 'open_settings',
      target: screen,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> openDialer(String number) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'open_dialer',
      target: number,
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openDialer(number);
    _audit(
      kind: 'open_dialer',
      target: number,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> browserSearch(String query) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'web_search',
      target: query,
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openBrowserSearch(query);
    _audit(
      kind: 'web_search',
      target: query,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> openSmsDraft({
    required String number,
    required String text,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'open_sms_draft',
      target: '$number ${_redact(text)}',
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openSmsDraft(number: number, text: text);
    _audit(
      kind: 'open_sms_draft',
      target: number,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> openDeviceAdmin() async {
    final policy = PhoneActionPolicy.classify(
      kind: 'open_settings',
      target: 'device_admin',
    );
    final result = await ref
        .read(deviceControlBridgeProvider)
        .openDeviceAdmin();
    await refresh();
    _audit(
      kind: 'permission',
      target: 'device_admin',
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> lockDevice({
    PhoneActionSurface surface = PhoneActionSurface.openClawConfirmed,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'device_admin',
      target: 'lock_device',
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref.read(deviceControlBridgeProvider).lockDevice();
    await refresh();
    _audit(
      kind: 'device_admin',
      target: 'lock_device',
      message: result.message,
      ok: result.ok,
      requiresAccessibility: false,
      policy: policy,
    );
    return result.message;
  }

  Future<String> press(
    String action, {
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'press_phone_button',
      target: action,
      requiresAccessibility: true,
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref
        .read(deviceControlBridgeProvider)
        .globalAction(action);
    await refresh();
    _audit(
      kind: 'accessibility_action',
      target: action,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return result.message;
  }

  Future<String> clickText(
    String text, {
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'click_text',
      target: text,
      requiresAccessibility: true,
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref.read(deviceControlBridgeProvider).clickText(text);
    await refresh();
    _audit(
      kind: 'click_text',
      target: text,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return result.message;
  }

  Future<String> typeText(
    String text, {
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) async {
    final redacted = _redact(text);
    final policy = PhoneActionPolicy.classify(
      kind: 'type_text',
      target: redacted,
      requiresAccessibility: true,
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref.read(deviceControlBridgeProvider).typeText(text);
    await refresh();
    _audit(
      kind: 'type_text',
      target: redacted,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return result.message;
  }

  Future<String> scroll(
    String direction, {
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'scroll',
      target: direction,
      requiresAccessibility: true,
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref
        .read(deviceControlBridgeProvider)
        .scroll(direction);
    await refresh();
    _audit(
      kind: 'scroll',
      target: direction,
      message: result.message,
      ok: result.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return result.message;
  }

  Future<String> tap({
    required double x,
    required double y,
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) async {
    final policy = PhoneActionPolicy.classify(
      kind: 'tap',
      target: '${x.round()},${y.round()}',
      requiresAccessibility: true,
    );
    if (!policy.canExecuteOn(surface)) {
      _auditDenied(policy);
      return policy.reason;
    }
    final result = await ref.read(deviceControlBridgeProvider).tap(x: x, y: y);
    await refresh();
    _audit(
      kind: 'tap',
      target: '${x.round()},${y.round()}',
      message: result.message,
      ok: result.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return result.message;
  }

  Future<String> tapVisibleNode(
    VisibleNode node, {
    PhoneActionSurface surface = PhoneActionSurface.agentDirect,
  }) {
    return tap(x: node.centerX, y: node.centerY, surface: surface);
  }

  Future<DeviceScreenSnapshot> readScreen() async {
    final policy = PhoneActionPolicy.classify(
      kind: 'read_screen',
      requiresAccessibility: true,
    );
    final snapshot = await ref.read(deviceControlBridgeProvider).readScreen();
    await refresh();
    final structured = StructuredScreen.fromSnapshot(snapshot);
    state = state.copyWith(
      lastSnapshot: snapshot,
      lastStructuredScreen: structured,
    );
    _audit(
      kind: 'read_screen',
      target: snapshot.packageName,
      message: snapshot.message,
      ok: snapshot.ok,
      requiresAccessibility: true,
      policy: policy,
    );
    return snapshot;
  }

  void clearAudit() => state = state.copyWith(audit: const []);

  void _audit({
    required String kind,
    required String target,
    required String message,
    required bool ok,
    required bool requiresAccessibility,
    required PhoneActionPolicyDecision policy,
  }) {
    final entry = PhoneControlAuditEntry(
      kind: kind,
      target: target,
      message: message,
      ok: ok,
      requiresAccessibility: requiresAccessibility,
      policyTier: policy.label,
      policyReason: policy.reason,
      at: DateTime.now(),
    );
    final next = [entry, ...state.audit].take(80).toList(growable: false);
    state = state.copyWith(audit: next, error: ok ? '' : message);
    _persistAudit(entry);
  }

  void _auditDenied(PhoneActionPolicyDecision policy) {
    _audit(
      kind: policy.kind,
      target: policy.target,
      message: policy.reason,
      ok: false,
      requiresAccessibility: policy.requiresAccessibility,
      policy: policy,
    );
  }

  String _redact(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 8) return 'text:${trimmed.length} chars';
    return 'text:${trimmed.length} chars:${trimmed.substring(0, 4)}...';
  }

  Future<void> _persistAudit(PhoneControlAuditEntry entry) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(contextOsDaoProvider).insertAuditEvent(
            AuditEventRecord(
              id: '',
              userId: userId,
              kind: 'phone_control',
              detail: entry.toAuditDetail(),
              edgeState: 'edge',
              metadata: entry.toJson(),
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }
}

class PhoneControlState {
  const PhoneControlState({
    this.accessibilityEnabled = false,
    this.deviceAdminStatus,
    this.audit = const [],
    this.lastSnapshot,
    this.lastStructuredScreen,
    this.error = '',
  });

  final bool accessibilityEnabled;
  final DeviceAdminStatus? deviceAdminStatus;
  final List<PhoneControlAuditEntry> audit;
  final DeviceScreenSnapshot? lastSnapshot;
  final StructuredScreen? lastStructuredScreen;
  final String error;

  PhoneControlState copyWith({
    bool? accessibilityEnabled,
    DeviceAdminStatus? deviceAdminStatus,
    List<PhoneControlAuditEntry>? audit,
    DeviceScreenSnapshot? lastSnapshot,
    StructuredScreen? lastStructuredScreen,
    String? error,
  }) {
    return PhoneControlState(
      accessibilityEnabled: accessibilityEnabled ?? this.accessibilityEnabled,
      deviceAdminStatus: deviceAdminStatus ?? this.deviceAdminStatus,
      audit: audit ?? this.audit,
      lastSnapshot: lastSnapshot ?? this.lastSnapshot,
      lastStructuredScreen: lastStructuredScreen ?? this.lastStructuredScreen,
      error: error ?? this.error,
    );
  }
}

class PhoneControlAuditEntry {
  const PhoneControlAuditEntry({
    required this.kind,
    required this.target,
    required this.message,
    required this.ok,
    required this.requiresAccessibility,
    required this.policyTier,
    required this.policyReason,
    required this.at,
  });

  final String kind;
  final String target;
  final String message;
  final bool ok;
  final bool requiresAccessibility;
  final String policyTier;
  final String policyReason;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'target': target,
    'message': message,
    'ok': ok,
    'requires_accessibility': requiresAccessibility,
    'policy_tier': policyTier,
    'policy_reason': policyReason,
    'at': at.toIso8601String(),
  };

  String toAuditDetail() {
    final status = ok ? 'ok' : 'blocked_or_failed';
    return '$kind [$policyTier/$status] $target -> $message';
  }
}

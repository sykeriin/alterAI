import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/application/backend_config_controller.dart';
import '../../backend/data/backend_api_client.dart';
import '../../contextos/application/openclaw_adapter.dart';
import '../../device_control/application/phone_control_controller.dart';
import '../../device_control/domain/screen_understanding.dart';
import '../data/device_actions.dart';
import 'notification_monitor.dart';
import 'persistent_intelligence_store.dart';

final agentExecutionRuntimeProvider =
    NotifierProvider<AgentExecutionRuntime, AgentExecutionState>(
      AgentExecutionRuntime.new,
    );

enum AgentSpecialist {
  coordinator('Coordinator'),
  planner('Planner'),
  phoneControl('Phone Control'),
  memory('Memory'),
  safety('Safety'),
  language('Language'),
  task('Task'),
  socialOpportunity('Social/Opportunity');

  const AgentSpecialist(this.label);
  final String label;
}

class AgentExecutionState {
  const AgentExecutionState({
    this.running = false,
    this.currentGoal = '',
    this.currentAgent = AgentSpecialist.coordinator,
    this.plan = const [],
    this.audit = const [],
    this.observations = const [],
    this.memoryUsed = const [],
    this.failures = const [],
  });

  final bool running;
  final String currentGoal;
  final AgentSpecialist currentAgent;
  final List<AgentRuntimeStep> plan;
  final List<AgentRuntimeAudit> audit;
  final List<String> observations;
  final List<String> memoryUsed;
  final List<String> failures;

  AgentExecutionState copyWith({
    bool? running,
    String? currentGoal,
    AgentSpecialist? currentAgent,
    List<AgentRuntimeStep>? plan,
    List<AgentRuntimeAudit>? audit,
    List<String>? observations,
    List<String>? memoryUsed,
    List<String>? failures,
  }) {
    return AgentExecutionState(
      running: running ?? this.running,
      currentGoal: currentGoal ?? this.currentGoal,
      currentAgent: currentAgent ?? this.currentAgent,
      plan: plan ?? this.plan,
      audit: audit ?? this.audit,
      observations: observations ?? this.observations,
      memoryUsed: memoryUsed ?? this.memoryUsed,
      failures: failures ?? this.failures,
    );
  }

  int get completedSteps =>
      plan.where((step) => step.status == AgentStepStatus.done).length;
}

enum AgentStepStatus { planned, running, done, blocked, failed }

class AgentRuntimeStep {
  const AgentRuntimeStep({
    required this.toolName,
    required this.title,
    required this.rationale,
    required this.agent,
    this.parameters = const {},
    this.requiresConfirmation = true,
    this.requiresAccessibility = false,
    this.status = AgentStepStatus.planned,
    this.result = '',
    this.blockedReason = '',
  });

  factory AgentRuntimeStep.fromBackend(Map<String, dynamic> json) {
    return AgentRuntimeStep(
      toolName: _string(json['tool_name'], fallback: 'assistant.respond'),
      title: _string(json['title'], fallback: 'Plan next step'),
      rationale: _string(json['rationale']),
      agent: _agentForTool(_string(json['tool_name'])),
      parameters: Map<String, Object?>.from(
        json['parameters'] as Map? ?? const <String, Object?>{},
      ),
      requiresConfirmation: json['requires_confirmation'] != false,
      requiresAccessibility: json['requires_accessibility'] == true,
      status: _string(json['status']) == 'blocked'
          ? AgentStepStatus.blocked
          : AgentStepStatus.planned,
      blockedReason: _string(json['blocked_reason']),
    );
  }

  final String toolName;
  final String title;
  final String rationale;
  final AgentSpecialist agent;
  final Map<String, Object?> parameters;
  final bool requiresConfirmation;
  final bool requiresAccessibility;
  final AgentStepStatus status;
  final String result;
  final String blockedReason;

  AgentRuntimeStep copyWith({
    AgentStepStatus? status,
    String? result,
    String? blockedReason,
  }) {
    return AgentRuntimeStep(
      toolName: toolName,
      title: title,
      rationale: rationale,
      agent: agent,
      parameters: parameters,
      requiresConfirmation: requiresConfirmation,
      requiresAccessibility: requiresAccessibility,
      status: status ?? this.status,
      result: result ?? this.result,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }
}

class AgentRuntimeAudit {
  const AgentRuntimeAudit({
    required this.kind,
    required this.summary,
    required this.ok,
    required this.at,
  });

  final String kind;
  final String summary;
  final bool ok;
  final DateTime at;
}

class AgentExecutionRuntime extends Notifier<AgentExecutionState> {
  @override
  AgentExecutionState build() => const AgentExecutionState();

  Future<void> runGoal(String goal) async {
    final trimmed = goal.trim();
    if (trimmed.isEmpty || state.running) return;

    state = AgentExecutionState(running: true, currentGoal: trimmed);
    await _store.addMemory(
      source: 'agent_goal',
      title: trimmed,
      summary: 'User asked ALTER to execute a smartphone goal.',
    );

    final plan = await _buildPlan(trimmed);
    state = state.copyWith(plan: plan, currentAgent: AgentSpecialist.planner);
    await _audit('plan', 'Built ${plan.length} step plan for "$trimmed".');

    for (var i = 0; i < plan.length && i < 8; i++) {
      if (!state.running) break;
      await _observe('before_step_${i + 1}');
      final step = state.plan[i];
      if (step.status == AgentStepStatus.blocked) {
        await _audit('blocked', step.blockedReason, ok: false);
        _replaceStep(i, step);
        continue;
      }
      await _executeStep(i, step);
      await _observe('after_step_${i + 1}');
    }

    await _audit('complete', 'Observe-plan-act loop finished.');
    state = state.copyWith(running: false);
  }

  void stop() {
    state = state.copyWith(running: false);
  }

  Future<void> clear() async {
    state = const AgentExecutionState();
  }

  PersistentIntelligenceStore get _store =>
      ref.read(persistentIntelligenceStoreProvider.notifier);

  Future<List<AgentRuntimeStep>> _buildPlan(String goal) async {
    final backendPlan = await _backendPlan(goal);
    if (backendPlan.isNotEmpty) return backendPlan;
    return _localPlan(goal);
  }

  Future<List<AgentRuntimeStep>> _backendPlan(String goal) async {
    try {
      final config = await ref.read(backendConfigProvider.future);
      if (!config.hasGateway) return const [];
      final client = BackendApiClient(baseUrl: config.gatewayUrl);
      final json = await client.postJson('/v1/agent/plan', {
        'goal': goal,
        'allowed_tools': const [
          'device_action.open_intent',
          'device_action.compose',
          'openclaw.accessibility_action',
          'assistant.respond',
        ],
      });
      client.close();
      final steps = json?['steps'];
      if (steps is! List) return const [];
      return steps
          .whereType<Map<String, dynamic>>()
          .map(AgentRuntimeStep.fromBackend)
          .toList(growable: false);
    } catch (error) {
      _failure('Backend planner unavailable: $error');
      return const [];
    }
  }

  List<AgentRuntimeStep> _localPlan(String goal) {
    final lower = goal.toLowerCase();
    final steps = <AgentRuntimeStep>[];
    if (lower.contains('whatsapp')) {
      steps.add(
        _step(
          toolName: 'device_action.open_intent',
          title: 'Open WhatsApp',
          agent: AgentSpecialist.phoneControl,
          parameters: {'app_name': 'whatsapp'},
          requiresConfirmation: false,
        ),
      );
    } else if (lower.contains('settings')) {
      steps.add(
        _step(
          toolName: 'device_action.open_intent',
          title: 'Open Android settings',
          agent: AgentSpecialist.phoneControl,
          parameters: {'screen': _settingsFromGoal(lower)},
          requiresConfirmation: false,
        ),
      );
    } else if (lower.contains('search')) {
      steps.add(
        _step(
          toolName: 'device_action.browser_search',
          title: 'Open browser search',
          agent: AgentSpecialist.task,
          parameters: {'query': goal},
          requiresConfirmation: false,
        ),
      );
    }
    if (lower.contains('reply') || lower.contains('draft')) {
      steps.add(
        _step(
          toolName: 'device_action.compose',
          title: 'Prepare a draft reply',
          agent: AgentSpecialist.phoneControl,
          parameters: {'instruction': goal},
        ),
      );
    }
    if (steps.isEmpty) {
      steps.add(
        _step(
          toolName: 'assistant.respond',
          title: 'Answer from assistant',
          agent: AgentSpecialist.coordinator,
          parameters: {'goal': goal},
          requiresConfirmation: false,
        ),
      );
    }
    return steps;
  }

  AgentRuntimeStep _step({
    required String toolName,
    required String title,
    required AgentSpecialist agent,
    required Map<String, Object?> parameters,
    bool requiresConfirmation = true,
  }) {
    return AgentRuntimeStep(
      toolName: toolName,
      title: title,
      rationale: 'Chosen by local multi-agent coordinator.',
      agent: agent,
      parameters: parameters,
      requiresConfirmation: requiresConfirmation,
      requiresAccessibility: toolName.contains('accessibility'),
    );
  }

  Future<void> _observe(String label) async {
    final phone = ref.read(phoneControlControllerProvider.notifier);
    final snapshot = await phone.readScreen();
    final structured = ref
        .read(phoneControlControllerProvider)
        .lastStructuredScreen;
    final summary =
        structured?.toAgentSummary(maxItems: 12) ?? snapshot.message;
    final next = [
      '$label: $summary',
      ...state.observations,
    ].take(20).toList(growable: false);
    state = state.copyWith(observations: next);
    await _store.addMemory(
      source: 'screen_observation',
      title: label,
      summary: summary,
      metadata: {'package': snapshot.packageName},
    );
  }

  Future<void> _executeStep(int index, AgentRuntimeStep step) async {
    _replaceStep(index, step.copyWith(status: AgentStepStatus.running));
    state = state.copyWith(currentAgent: step.agent);
    final result = await _runTool(step);
    final ok =
        !result.toLowerCase().contains('blocked') &&
        !result.toLowerCase().contains('could not') &&
        !result.toLowerCase().contains('not enabled');
    _replaceStep(
      index,
      step.copyWith(
        status: ok ? AgentStepStatus.done : AgentStepStatus.failed,
        result: result,
      ),
    );
    await _audit(step.toolName, result, ok: ok);
  }

  Future<String> _runTool(AgentRuntimeStep step) async {
    final phone = ref.read(phoneControlControllerProvider.notifier);
    final device = const DeviceActions();
    final args = step.parameters;
    final goal = state.currentGoal;
    final lowerGoal = goal.toLowerCase();

    switch (step.toolName) {
      case 'device_action.open_intent':
        final appName = _arg(
          args,
          'app_name',
          fallback: _appFromGoal(lowerGoal),
        );
        final packageName = _arg(args, 'package_name');
        final screen = _arg(args, 'screen');
        final query = _arg(args, 'query', fallback: goal);
        if (screen.isNotEmpty || lowerGoal.contains('settings')) {
          return phone.openSettings(
            screen.isNotEmpty ? screen : _settingsFromGoal(lowerGoal),
          );
        }
        if (lowerGoal.contains('search') || lowerGoal.contains('browser')) {
          return phone.browserSearch(query);
        }
        return phone.openApp(appName: appName, packageName: packageName);
      case 'device_action.browser_search':
        return phone.browserSearch(_arg(args, 'query', fallback: goal));
      case 'device_action.compose':
        return _compose(args, goal);
      case 'openclaw.accessibility_action':
        return _accessibilityAction(args, goal);
      case 'assistant.respond':
        return 'No phone action needed. ALTER can answer this directly.';
      default:
        if (step.toolName.contains('notification_reply')) {
          return ref
              .read(notificationMonitorProvider.notifier)
              .replyToLatest(text: _arg(args, 'text', fallback: goal));
        }
        if (step.toolName.contains('web_search')) {
          return device.webSearch(_arg(args, 'query', fallback: goal));
        }
        return 'No executor mapping for ${step.toolName}.';
    }
  }

  Future<String> _compose(Map<String, Object?> args, String goal) async {
    final phone = ref.read(phoneControlControllerProvider.notifier);
    final device = const DeviceActions();
    final lower = goal.toLowerCase();
    final number = _firstPhoneNumber(goal);
    final text = _draftText(goal);
    if (lower.contains('sms') && number.isNotEmpty) {
      return phone.openSmsDraft(number: number, text: text);
    }
    if (lower.contains('whatsapp')) {
      if (number.isNotEmpty) {
        return device.sendMessage(app: 'whatsapp', number: number, text: text);
      }
      await ref
          .read(openClawQueueProvider.notifier)
          .enqueueStructured(
            type: 'draft_reply',
            title: 'Draft reply',
            detail: text,
          );
      return 'Queued a reply draft in OpenClaw because no phone number was available.';
    }
    await ref
        .read(openClawQueueProvider.notifier)
        .enqueueStructured(
          type: 'draft_reply',
          title: 'Draft reply',
          detail: text,
        );
    return 'Queued a reply draft in OpenClaw for review.';
  }

  Future<String> _accessibilityAction(Map<String, Object?> args, String goal) {
    final phone = ref.read(phoneControlControllerProvider.notifier);
    final instruction = _arg(args, 'instruction', fallback: goal).toLowerCase();
    if (instruction.contains('scroll')) {
      return phone.scroll(instruction.contains('up') ? 'backward' : 'forward');
    }
    if (instruction.contains('back')) return phone.press('back');
    if (instruction.contains('home')) return phone.press('home');
    if (instruction.contains('type')) {
      return phone.typeText(_draftText(goal));
    }
    final structured = ref
        .read(phoneControlControllerProvider)
        .lastStructuredScreen;
    final target = _firstSafeButton(structured?.buttons ?? const []);
    if (target != null) {
      return phone.tap(x: target.centerX, y: target.centerY);
    }
    return Future.value('No safe visible element was selected for tapping.');
  }

  void _replaceStep(int index, AgentRuntimeStep step) {
    final next = [...state.plan];
    if (index >= 0 && index < next.length) next[index] = step;
    state = state.copyWith(plan: next);
  }

  Future<void> _audit(String kind, String summary, {bool ok = true}) async {
    final entry = AgentRuntimeAudit(
      kind: kind,
      summary: summary,
      ok: ok,
      at: DateTime.now(),
    );
    state = state.copyWith(
      audit: [entry, ...state.audit].take(80).toList(growable: false),
    );
    await _store.recordAudit(
      kind: 'agent_runtime:$kind',
      summary: summary,
      status: ok ? 'ok' : 'failed',
    );
  }

  void _failure(String message) {
    state = state.copyWith(
      failures: [message, ...state.failures].take(20).toList(growable: false),
    );
  }
}

AgentSpecialist _agentForTool(String toolName) {
  if (toolName.contains('accessibility') ||
      toolName.contains('device_action')) {
    return AgentSpecialist.phoneControl;
  }
  if (toolName.contains('memory')) return AgentSpecialist.memory;
  if (toolName.contains('language')) return AgentSpecialist.language;
  return AgentSpecialist.planner;
}

String _arg(Map<String, Object?> args, String key, {String fallback = ''}) {
  final value = args[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

String _appFromGoal(String goal) {
  if (goal.contains('whatsapp')) return 'whatsapp';
  if (goal.contains('gmail')) return 'gmail';
  if (goal.contains('chrome')) return 'chrome';
  if (goal.contains('messages') || goal.contains('sms')) return 'messages';
  if (goal.contains('calendar')) return 'calendar';
  return '';
}

String _settingsFromGoal(String goal) {
  if (goal.contains('accessibility')) return 'accessibility';
  if (goal.contains('notification')) return 'notifications';
  if (goal.contains('wifi')) return 'wifi';
  if (goal.contains('bluetooth')) return 'bluetooth';
  if (goal.contains('battery')) return 'battery';
  if (goal.contains('privacy')) return 'privacy';
  return 'general';
}

String _firstPhoneNumber(String text) {
  return RegExp(
        r'\+?\d[\d\s().-]{6,}\d',
      ).firstMatch(text)?.group(0)?.replaceAll(RegExp(r'[^\d+]'), '') ??
      '';
}

String _draftText(String goal) {
  final quoted = RegExp(r'"([^"]+)"').firstMatch(goal)?.group(1);
  if (quoted != null && quoted.trim().isNotEmpty) return quoted.trim();
  if (goal.toLowerCase().contains('reply')) {
    return 'Thanks, I saw this. I will get back to you shortly.';
  }
  return goal;
}

String _string(Object? raw, {String fallback = ''}) {
  return raw is String && raw.isNotEmpty ? raw : fallback;
}

ScreenElement? _firstSafeButton(Iterable<ScreenElement> buttons) {
  for (final button in buttons) {
    if (!button.policy.requiresConfirmation) return button;
  }
  return null;
}

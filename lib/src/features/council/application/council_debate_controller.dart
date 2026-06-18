import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/alter_palette.dart';
import '../../backend/application/backend_config_controller.dart';
import '../../backend/data/backend_feature_api_client.dart';
import '../../profile/application/profile_provider.dart';
import '../../profile/domain/user_profile.dart';
import '../../shared/application/alter_data_providers.dart';

final councilDebateControllerProvider =
    NotifierProvider<CouncilDebateController, CouncilDebateState>(
      CouncilDebateController.new,
    );

enum AgentStatus { idle, thinking, done, failed }

class AgentDebateEntry {
  const AgentDebateEntry({
    required this.name,
    required this.role,
    required this.accent,
    this.status = AgentStatus.idle,
    this.response = '',
  });

  final String name;
  final String role;
  final Color accent;
  final AgentStatus status;
  final String response;

  AgentDebateEntry copyWith({AgentStatus? status, String? response}) =>
      AgentDebateEntry(
        name: name,
        role: role,
        accent: accent,
        status: status ?? this.status,
        response: response ?? this.response,
      );
}

class CouncilDebateState {
  const CouncilDebateState({
    this.topic = '',
    this.isDebating = false,
    this.entries = const [],
    this.consensus = '',
    this.steps = const [],
    this.error = '',
  });

  final String topic;
  final bool isDebating;
  final List<AgentDebateEntry> entries;
  final String consensus;
  final List<String> steps;
  final String error;

  bool get hasResult => steps.isNotEmpty || consensus.isNotEmpty;

  CouncilDebateState copyWith({
    String? topic,
    bool? isDebating,
    List<AgentDebateEntry>? entries,
    String? consensus,
    List<String>? steps,
    String? error,
  }) => CouncilDebateState(
    topic: topic ?? this.topic,
    isDebating: isDebating ?? this.isDebating,
    entries: entries ?? this.entries,
    consensus: consensus ?? this.consensus,
    steps: steps ?? this.steps,
    error: error ?? this.error,
  );
}

class CouncilDebateController extends Notifier<CouncilDebateState> {
  static const _agentDefs = [
    (
      name: 'Strategist',
      role: 'Market timing & positioning',
      accent: AlterPalette.iris,
      system:
          'You are the Strategist: a market timing and positioning expert. Give your strategic perspective in 2-3 crisp sentences. Be decisive and specific to the situation.',
    ),
    (
      name: 'Operator',
      role: 'Execution & operations',
      accent: AlterPalette.cyan,
      system:
          'You are the Operator: an execution and operations expert. Focus on concrete next steps, timelines, and constraints. Give 2-3 direct sentences.',
    ),
    (
      name: 'Contrarian',
      role: 'Risk & devil\'s advocate',
      accent: AlterPalette.aura,
      system:
          'You are the Contrarian: a risk analyst and devil\'s advocate. Challenge assumptions and identify blind spots others miss. Give 2-3 critical but constructive sentences.',
    ),
    (
      name: 'Connector',
      role: 'Network & relationships',
      accent: AlterPalette.mint,
      system:
          'You are the Connector: a network and relationships expert. Identify who to talk to, warm paths, and how to leverage relationships. Give 2-3 specific sentences.',
    ),
  ];

  @override
  CouncilDebateState build() => const CouncilDebateState();

  Future<void> debate(String topic) async {
    if (topic.trim().isEmpty) return;

    state = CouncilDebateState(
      topic: topic,
      isDebating: true,
      entries: _agentDefs
          .map(
            (a) => AgentDebateEntry(
              name: a.name,
              role: a.role,
              accent: a.accent,
              status: AgentStatus.thinking,
            ),
          )
          .toList(),
    );

    final profile = ref.read(userProfileProvider).asData?.value;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    Object? backendError;
    final config = await ref.read(backendConfigProvider.future);
    final serviceUrl = config.gatewayUrl;
    if (serviceUrl.isNotEmpty) {
      final client = BackendFeatureApiClient(baseUrl: serviceUrl);
      try {
        final result = await client.runCouncilDebate(
          topic: topic,
          profile: profile,
          userId: userId,
        );
        client.close();
        state = state.copyWith(
          isDebating: false,
          entries: [
            for (final entry in result.entries)
              AgentDebateEntry(
                name: entry.name,
                role: entry.role,
                accent: entry.accent,
                status: AgentStatus.done,
                response: entry.response,
              ),
          ],
          consensus: result.consensus,
          steps: result.steps,
          error: '',
        );
        await _persistAgents(state.entries, topic);
        return;
      } catch (error) {
        backendError = error;
        client.close();
      }
    }

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      final backendMessage = backendError == null
          ? ''
          : ' Backend failed: ${backendError.toString().replaceFirst('Exception: ', '')}';
      state = state.copyWith(
        isDebating: false,
        error:
            'Connect the backend gateway or sign in with AI access.$backendMessage',
      );
      return;
    }

    final userContext = _buildUserContext(profile, topic);

    await Future.wait([
      for (final (idx, def) in _agentDefs.indexed)
        _queryAgent(idx, def.name, def.system, userContext),
    ]);

    final done = state.entries
        .where((e) => e.status == AgentStatus.done)
        .toList();
    if (done.isEmpty) {
      state = state.copyWith(
        isDebating: false,
        error: 'All agents failed. Check your AI access or backend gateway.',
      );
      return;
    }

    final summaries = done.map((e) => '${e.name}: ${e.response}').join('\n\n');

    try {
      final consensusRaw = await openai.chat(
        messages: [
          {
            'role': 'system',
            'content':
                'Synthesize council debate into 3 decisive action steps. Output ONLY 3 numbered lines: "1. ...", "2. ...", "3. ...". Nothing else.',
          },
          {
            'role': 'user',
            'content':
                'Topic: $topic\n\nCouncil:\n$summaries\n\n3 action steps:',
          },
        ],
        temperature: 0.4,
        maxTokens: 300,
      );

      final steps = _parseSteps(consensusRaw);

      state = state.copyWith(
        isDebating: false,
        consensus: consensusRaw,
        steps: steps,
      );

      await _persistAgents(state.entries, topic);
    } catch (e) {
      state = state.copyWith(
        isDebating: false,
        error:
            'Consensus failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _queryAgent(
    int idx,
    String name,
    String system,
    String userContext,
  ) async {
    final openai = ref.read(openAIServiceProvider);
    if (openai == null) return;

    try {
      final response = await openai.chat(
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': userContext},
        ],
        temperature: 0.82,
        maxTokens: 220,
      );

      final updated = [
        for (var i = 0; i < state.entries.length; i++)
          i == idx
              ? state.entries[i].copyWith(
                  status: AgentStatus.done,
                  response: response,
                )
              : state.entries[i],
      ];
      state = state.copyWith(entries: updated);
    } catch (e) {
      final updated = [
        for (var i = 0; i < state.entries.length; i++)
          i == idx
              ? state.entries[i].copyWith(
                  status: AgentStatus.failed,
                  response: e.toString().replaceFirst('Exception: ', ''),
                )
              : state.entries[i],
      ];
      state = state.copyWith(entries: updated);
    }
  }

  String _buildUserContext(UserProfile? profile, String topic) {
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'the user';
    final parts = ['$name needs strategic advice on: $topic'];
    if (profile?.role.isNotEmpty == true) parts.add('Role: ${profile!.role}');
    if (profile?.goals.isNotEmpty == true) {
      parts.add('Goals: ${profile!.goals.join(', ')}');
    }
    return parts.join('\n');
  }

  List<String> _parseSteps(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => RegExp(r'^\d+[.)]').hasMatch(l))
        .map((l) => l.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .toList();
  }

  Future<void> _persistAgents(
    List<AgentDebateEntry> entries,
    String topic,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('clone_agents')
          .delete()
          .eq('user_id', userId);

      await Supabase.instance.client.from('clone_agents').insert([
        for (final e in entries.where((e) => e.status == AgentStatus.done))
          {
            'user_id': userId,
            'name': e.name,
            'role': e.role,
            'state': 'Done',
            'confidence': 0.80 + (e.name.length % 8) * 0.02,
            'accent_hex':
                '#${e.accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            'summary': e.response,
          },
      ]);

      ref.invalidate(cloneCouncilProvider);
    } catch (_) {}
  }
}

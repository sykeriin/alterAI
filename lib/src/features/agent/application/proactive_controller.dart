import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/application/feature_live_providers.dart';
import '../../backend/application/life_os_providers.dart';
import '../../profile/application/profile_provider.dart';
import 'persistent_intelligence_store.dart';

/// One proactive suggestion ALTER surfaces without being asked. [action] is a
/// first-person command the user can tap to have ALTER act on it.
class ProactiveNudge {
  const ProactiveNudge({
    required this.title,
    required this.why,
    required this.action,
  });

  final String title;
  final String why;
  final String action;
}

/// Reads the user's twin (profile, recent memories, decision patterns) plus
/// their live day and open opportunities, then asks the model to propose up to
/// three tailored nudges. Returns an empty list when cloud AI is unavailable.
final proactiveNudgesProvider =
    FutureProvider.autoDispose<List<ProactiveNudge>>((ref) async {
  final openai = ref.read(openAIServiceProvider);
  if (openai == null) return const [];

  final ctx = StringBuffer();

  final profile = ref.read(userProfileProvider).asData?.value;
  if (profile != null) {
    final bits = <String>[
      if (profile.displayName.isNotEmpty) profile.displayName,
      if (profile.role.isNotEmpty) profile.role,
    ];
    ctx.writeln('User: ${bits.join(', ')}.');
    if (profile.skills.isNotEmpty) {
      ctx.writeln('Skills: ${profile.skills.take(10).join(', ')}.');
    }
    if (profile.goals.isNotEmpty) {
      ctx.writeln('Goals: ${profile.goals.take(6).join(', ')}.');
    }
  }

  // Live day (focus + a couple of tasks).
  try {
    final feed = await ref.watch(lifeFeedProvider.future);
    if (feed != null) {
      final focus = feed['focus_title'];
      if (focus != null && focus.toString().isNotEmpty) {
        ctx.writeln("Today's focus: $focus.");
      }
      final tasks = feed['tasks'];
      if (tasks is List && tasks.isNotEmpty) {
        final names = tasks
            .whereType<Map<dynamic, dynamic>>()
            .where((t) => t['done'] != true)
            .map((t) => t['title']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .take(3)
            .join('; ');
        if (names.isNotEmpty) ctx.writeln('Open tasks: $names.');
      }
    }
  } catch (_) {}

  // Open opportunities.
  try {
    final opps = await ref.watch(opportunitiesProvider.future);
    if (opps.isNotEmpty) {
      ctx.writeln(
          'Open opportunities: ${opps.take(3).map((o) => o.title).join('; ')}.');
    }
  } catch (_) {}

  // Recent twin memories.
  try {
    final mems = await ref
        .read(persistentIntelligenceStoreProvider.notifier)
        .searchMemory('');
    if (mems.isNotEmpty) {
      final recent = mems
          .take(4)
          .map((m) => m.title.isNotEmpty ? m.title : m.summary)
          .where((t) => t.isNotEmpty)
          .join('; ');
      if (recent.isNotEmpty) {
        ctx.writeln('Recently learned about them: $recent.');
      }
    }
  } catch (_) {}

  final messages = <Map<String, dynamic>>[
    {
      'role': 'system',
      'content':
          'You are ALTER, a proactive personal life OS. From what you know '
              'about the user, propose up to 3 SHORT, specific, genuinely '
              'helpful nudges they did NOT ask for — things worth doing now. '
              'Respond with ONLY compact JSON: a list of objects '
              '{"title","why","action"}. "title" <= 6 words. "why" is one '
              'short sentence grounded in their context. "action" is a '
              'first-person command the user could tap to have you act (e.g. '
              '"Draft my application to the AI internship"). No markdown, no '
              'prose outside the JSON.',
    },
    {
      'role': 'user',
      'content': ctx.toString().trim().isEmpty
          ? 'Limited context. Suggest 2 broadly useful nudges for someone '
              'building their career.'
          : ctx.toString(),
    },
  ];

  try {
    final raw = await openai.chat(messages: messages);
    return _parseNudges(raw);
  } catch (_) {
    return const [];
  }
});

List<ProactiveNudge> _parseNudges(String raw) {
  var text = raw.trim();
  // Strip ``` / ```json fences if the model added them.
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').trim();
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
  }
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start == -1 || end == -1 || end <= start) return const [];
  try {
    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is! List) return const [];
    final out = <ProactiveNudge>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString().trim();
      final action = (item['action'] ?? '').toString().trim();
      if (title.isEmpty || action.isEmpty) continue;
      out.add(ProactiveNudge(
        title: title,
        why: (item['why'] ?? '').toString().trim(),
        action: action,
      ));
      if (out.length >= 3) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

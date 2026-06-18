import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/feature_live_providers.dart';
import 'life_os_style.dart';

const _accents = [lLime, lCyan, lPurple, lPink, lOrange, lGreen];

class CouncilOsScreen extends ConsumerStatefulWidget {
  const CouncilOsScreen({super.key});

  @override
  ConsumerState<CouncilOsScreen> createState() => _CouncilOsScreenState();
}

class _CouncilOsScreenState extends ConsumerState<CouncilOsScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(cloneAgentsProvider);
    final debate = ref.watch(councilDebateProvider);
    final notifier = ref.read(councilDebateProvider.notifier);
    final d = debate.debate;

    return LifeOsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LifeOsHeader(
            kicker: 'Clone Council',
            title: 'Your inner\nboard of you.',
            accent: lPurple,
          ),
          const SizedBox(height: 16),
          LifeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: lTextHi),
                  cursorColor: lPurple,
                  onChanged: notifier.setTopic,
                  decoration: const InputDecoration(
                    hintText: 'Ask the council… e.g. “Should I take the offer?”',
                    hintStyle: TextStyle(color: lTextLo),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: LimePill(
                    label: debate.loading ? 'Deliberating…' : 'Convene council',
                    icon: debate.loading ? LucideIcons.loader : LucideIcons.users,
                    onTap: debate.loading ? null : notifier.run,
                  ),
                ),
              ],
            ),
          ),
          if (debate.error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(debate.error,
                style: const TextStyle(color: lOrange, fontSize: 12.5)),
          ],
          if (d != null) ...[
            const SizedBox(height: 16),
            if (d.consensus.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    lPurple.withValues(alpha: 0.2),
                    lPink.withValues(alpha: 0.12),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: lPurple.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(LucideIcons.gavel, color: lPurple, size: 18),
                        SizedBox(width: 8),
                        Text('CONSENSUS',
                            style: TextStyle(
                                color: lPurple,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(d.consensus,
                        style: const TextStyle(
                            color: lTextHi, height: 1.45, fontSize: 14)),
                  ],
                ),
              ),
            for (var i = 0; i < d.entries.length; i++) ...[
              const SizedBox(height: 12),
              _VoiceCard(
                name: d.entries[i].name,
                role: d.entries[i].role,
                response: d.entries[i].response,
                accent: _accents[i % _accents.length],
              ),
            ],
            if (d.steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              LifeCard(
                accent: lLime,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACTION PLAN',
                        style: TextStyle(
                            color: lLime,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 11)),
                    const SizedBox(height: 10),
                    for (var i = 0; i < d.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}',
                                style: const TextStyle(
                                    color: lLime,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(d.steps[i],
                                  style: const TextStyle(
                                      color: lTextHi, height: 1.4, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(LucideIcons.users, size: 16, color: lPurple),
                SizedBox(width: 8),
                Text('The council',
                    style: TextStyle(
                        color: lTextHi,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            agents.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator(color: lPurple)),
              ),
              error: (e, _) => Text(
                'Council unreachable — restart the gateway to enable '
                '/v1/clone-council.\n$e',
                style: const TextStyle(color: lTextLo, height: 1.4, fontSize: 12.5),
              ),
              data: (list) => list.isEmpty
                  ? const Text(
                      'No council members yet.',
                      style: TextStyle(color: lTextLo),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AgentCard(
                              name: list[i].name,
                              role: list[i].role,
                              summary: list[i].summary,
                              confidence: list[i].confidence,
                              accent: _accents[i % _accents.length],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.name,
    required this.role,
    required this.summary,
    required this.confidence,
    required this.accent,
  });

  final String name;
  final String role;
  final String summary;
  final double confidence;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LifeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(LucideIcons.bot, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: lTextHi,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text(role,
                        style: TextStyle(color: accent, fontSize: 12)),
                  ],
                ),
              ),
              if (confidence > 0) ScoreRing(value: confidence, color: accent, size: 40),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(summary,
                style: const TextStyle(color: lTextLo, height: 1.4, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.name,
    required this.role,
    required this.response,
    required this.accent,
  });

  final String name;
  final String role;
  final String response;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LifeCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.message_square, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      color: lTextHi,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              const SizedBox(width: 6),
              Text('· $role',
                  style: TextStyle(color: accent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(response,
              style: const TextStyle(color: lTextHi, height: 1.45, fontSize: 13.5)),
        ],
      ),
    );
  }
}

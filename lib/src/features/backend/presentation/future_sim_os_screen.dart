import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/life_os_providers.dart';
import 'life_os_style.dart';

class FutureSimOsScreen extends ConsumerStatefulWidget {
  const FutureSimOsScreen({super.key});

  @override
  ConsumerState<FutureSimOsScreen> createState() => _FutureSimOsScreenState();
}

class _FutureSimOsScreenState extends ConsumerState<FutureSimOsScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(futureTwinProvider);
    final notifier = ref.read(futureTwinProvider.notifier);
    final r = state.result;

    return LifeOsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LifeOsHeader(
            kicker: 'Future Simulator',
            title: 'Simulate your\nnext 90 days.',
            accent: lCyan,
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
                  cursorColor: lCyan,
                  onChanged: notifier.setObjective,
                  decoration: const InputDecoration(
                    hintText: 'e.g. “Become an ML engineer”',
                    hintStyle: TextStyle(color: lTextLo),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: LimePill(
                    label: state.loading ? 'Simulating…' : 'Simulate future',
                    icon: state.loading ? LucideIcons.loader : LucideIcons.git_fork,
                    onTap: state.loading ? null : notifier.simulate,
                  ),
                ),
              ],
            ),
          ),
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(state.error,
                style: const TextStyle(color: lOrange, fontSize: 12.5)),
          ],
          if (r != null) ...[
            const SizedBox(height: 16),
            _Result(r: r),
          ],
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.r});

  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final identity = (r['identity_summary'] ?? '').toString();
    final dailyQ = (r['daily_question'] ?? '').toString();
    final traj = r['trajectory'] is Map
        ? Map<String, dynamic>.from(r['trajectory'] as Map)
        : const <String, dynamic>{};
    final options = (r['future_options'] is List)
        ? (r['future_options'] as List)
        : const <dynamic>[];
    final action = r['action'] is Map
        ? Map<String, dynamic>.from(r['action'] as Map)
        : const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (identity.isNotEmpty)
          LifeCard(
            accent: lCyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Identity trajectory', lCyan),
                const SizedBox(height: 8),
                Text(identity,
                    style: const TextStyle(
                        color: lTextHi, height: 1.45, fontSize: 14)),
              ],
            ),
          ),
        if (dailyQ.isNotEmpty) ...[
          const SizedBox(height: 12),
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
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles, color: lPurple, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Daily question', lPurple),
                      const SizedBox(height: 4),
                      Text(dailyQ,
                          style: const TextStyle(
                              color: lTextHi,
                              fontWeight: FontWeight.w700,
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (traj.isNotEmpty) ...[
          const SizedBox(height: 12),
          LifeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Trajectory', lLime),
                const SizedBox(height: 10),
                _TrajLine('Now', (traj['current_trajectory'] ?? '').toString(), lTextLo),
                _TrajLine('90 days', (traj['predicted_90_day_future'] ?? '').toString(), lCyan),
                _TrajLine('Best case', (traj['best_alternative_future'] ?? '').toString(), lLime),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric('Alignment', lDouble(traj['alignment_score']), lLime),
                    _Metric('Velocity', lDouble(traj['execution_velocity']), lCyan),
                    _Metric('Drift', lDouble(traj['drift_risk']), lOrange),
                  ],
                ),
              ],
            ),
          ),
        ],
        for (final o in options)
          if (o is Map) ...[
            const SizedBox(height: 12),
            _OptionCard(o: Map<String, dynamic>.from(o)),
          ],
        if (action.isNotEmpty) ...[
          const SizedBox(height: 12),
          LifeCard(
            accent: lLime,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Highest-leverage move', lLime),
                const SizedBox(height: 8),
                Text((action['title'] ?? '').toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                if ((action['first_step'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('First step: ${action['first_step']}',
                      style: const TextStyle(color: lTextLo, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.o});

  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final prob = lDouble(o['success_probability']);
    return LifeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(value: prob, color: lCyan),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((o['name'] ?? 'Path').toString(),
                    style: const TextStyle(
                        color: lTextHi,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text((o['thesis'] ?? '').toString(),
                    style: const TextStyle(
                        color: lTextLo, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrajLine extends StatelessWidget {
  const _TrajLine(this.label, this.text, this.color);
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: lTextHi, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('${(value * 100).round()}',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: const TextStyle(color: lTextLo, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 11,
        ),
      );
}

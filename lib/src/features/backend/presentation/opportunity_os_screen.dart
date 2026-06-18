import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/alter_models.dart' as alter;
import '../application/feature_live_providers.dart';
import 'life_os_style.dart';

class OpportunityOsScreen extends ConsumerWidget {
  const OpportunityOsScreen({super.key});

  static const _catColors = {
    'hackathon': lPink,
    'internship': lCyan,
    'grant': lLime,
    'scholarship': lLime,
    'open-source': lPurple,
    'open_source': lPurple,
    'research': lOrange,
    'job': lCyan,
  };

  Color _catColor(String cat) =>
      _catColors[cat.toLowerCase().replaceAll(' ', '-')] ?? lPurple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opps = ref.watch(opportunitiesProvider);
    return LifeOsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LifeOsHeader(
            kicker: 'Opportunity Radar',
            title: 'Matched\nto you.',
            accent: lOrange,
            trailing: IconButton(
              icon: const Icon(LucideIcons.refresh_cw, size: 18, color: lTextLo),
              onPressed: () => ref.invalidate(opportunitiesProvider),
            ),
          ),
          const SizedBox(height: 16),
          opps.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: lOrange)),
            ),
            error: (e, _) => Text(
              'Radar unreachable — restart the gateway to enable '
              '/v1/opportunities.\n$e',
              style: const TextStyle(color: lTextLo, height: 1.4, fontSize: 12.5),
            ),
            data: (list) => list.isEmpty
                ? _EmptyProfile(onSetup: () => context.go('/profile'))
                : Column(
                    children: [
                      for (final o in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OppCard(o: o, color: _catColor(o.category)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OppCard extends StatelessWidget {
  const _OppCard({required this.o, required this.color});

  final alter.OpportunitySignal o;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LifeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScoreRing(value: o.score, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        o.category.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(o.title,
                        style: const TextStyle(
                            color: lTextHi,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
          if (o.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(o.evidence,
                style: const TextStyle(color: lTextLo, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.building_2, size: 13, color: lTextLo),
              const SizedBox(width: 5),
              Flexible(
                child: Text(o.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: lTextLo, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.clock, size: 13, color: lTextLo),
              const SizedBox(width: 5),
              Flexible(
                child: Text(o.window,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: lTextLo, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          const Icon(LucideIcons.radar, size: 42, color: lOrange),
          const SizedBox(height: 14),
          const Text('No matches yet',
              style: TextStyle(
                  color: lTextHi, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 8),
          const Text(
            'The radar matches opportunities to your skills, goals and '
            'interests. Add them to your profile to get real matches.',
            textAlign: TextAlign.center,
            style: TextStyle(color: lTextLo, height: 1.45),
          ),
          const SizedBox(height: 16),
          LimePill(
            label: 'Set up profile',
            icon: LucideIcons.user_pen,
            onTap: onSetup,
          ),
        ],
      ),
    );
  }
}

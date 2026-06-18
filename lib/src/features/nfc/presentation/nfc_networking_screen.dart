import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/nfc_networking_controller.dart';
import '../domain/nfc_match.dart';
import '../domain/nfc_profile.dart';

class NfcNetworkingScreen extends ConsumerWidget {
  const NfcNetworkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nfcNetworkingControllerProvider);
    final controller = ref.read(nfcNetworkingControllerProvider.notifier);
    final theme = Theme.of(context);
    final result = state.lastResult;

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      'NFC Networking',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap phones. Exchange context. Leave with a ranked reason to follow up.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!context.isCompact) ...[
                const SizedBox(width: 14),
                PremiumChip(
                  label: state.availability?.name ?? 'ready',
                  selected: state.phase != NfcNetworkingPhase.error,
                  icon: LucideIcons.shield_check,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              _TapPanel(
                state: state,
                onScan: controller.scanAndMatch,
                onShare: controller.shareProfile,
                onCheck: controller.refreshAvailability,
                onTapShare: controller.shareViaTap,
                onStopShare: controller.stopTapShare,
              ),
              _ExchangeBundle(profile: state.localProfile),
              _ScoreStack(result: result),
            ],
          ),
          const SizedBox(height: 18),
          if (state.errorMessage.isNotEmpty)
            _StatusPanel(message: state.errorMessage, isError: true),
          if (result != null) ...[
            _ResultPanel(result: result),
            const SizedBox(height: 18),
            ResponsiveGrid(
              mediumColumns: 3,
              expandedColumns: 3,
              children: [
                for (final signal in result.signals)
                  _SignalCard(signal: signal),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TapPanel extends StatelessWidget {
  const _TapPanel({
    required this.state,
    required this.onScan,
    required this.onShare,
    required this.onCheck,
    required this.onTapShare,
    required this.onStopShare,
  });

  final NfcNetworkingState state;
  final VoidCallback onScan;
  final VoidCallback onShare;
  final VoidCallback onCheck;
  final VoidCallback onTapShare;
  final VoidCallback onStopShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final broadcasting = state.phase == NfcNetworkingPhase.broadcasting;
    final status = switch (state.phase) {
      NfcNetworkingPhase.checking => 'Checking NFC',
      NfcNetworkingPhase.scanning => 'Listening for tap',
      NfcNetworkingPhase.writing => 'Sharing profile',
      NfcNetworkingPhase.broadcasting => 'Hold near another phone',
      NfcNetworkingPhase.matched => 'Match created',
      NfcNetworkingPhase.unavailable => 'NFC unavailable',
      NfcNetworkingPhase.error => 'Needs attention',
      NfcNetworkingPhase.idle => 'Ready to tap',
    };

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Tap Exchange',
            subtitle: status,
            trailing: IconButton(
              tooltip: 'Check NFC',
              onPressed: state.isBusy ? null : onCheck,
              icon: const Icon(LucideIcons.radar),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 172,
            child: Center(
              child: _NfcPulse(isActive: state.isBusy || broadcasting),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            state.localProfile.displayName.isEmpty
                ? 'Complete your profile'
                : state.localProfile.displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              state.localProfile.role,
              state.localProfile.location,
            ].where((item) => item.trim().isNotEmpty).join(' - '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: broadcasting
                ? [
                    PremiumButton(
                      label: 'Stop sharing',
                      icon: LucideIcons.square,
                      compact: true,
                      onPressed: onStopShare,
                    ),
                  ]
                : [
                    PremiumButton(
                      label: 'Receive',
                      icon: LucideIcons.nfc,
                      compact: true,
                      onPressed: state.isBusy ? null : onScan,
                    ),
                    PremiumButton(
                      label: 'Tap to share',
                      icon: LucideIcons.radio,
                      compact: true,
                      onPressed: state.isBusy ? null : onTapShare,
                    ),
                    PremiumButton(
                      label: 'Write tag',
                      icon: LucideIcons.network,
                      compact: true,
                      onPressed: state.isBusy ? null : onShare,
                    ),
                  ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms).moveY(begin: 10, end: 0);
  }
}

class _NfcPulse extends StatelessWidget {
  const _NfcPulse({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
          painter: _NfcPulsePainter(isActive: isActive),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AlterPalette.premiumGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AlterPalette.iris.withValues(alpha: 0.28),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: const SizedBox(
              width: 96,
              height: 96,
              child: Icon(LucideIcons.nfc, color: Colors.white, size: 36),
            ),
          ),
        )
        .animate(
          onPlay: (controller) {
            if (isActive) {
              controller.repeat(reverse: true);
            }
          },
        )
        .scaleXY(
          begin: 0.96,
          end: isActive ? 1.05 : 1,
          duration: 920.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _NfcPulsePainter extends CustomPainter {
  const _NfcPulsePainter({required this.isActive});

  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius = 56.0 + i * 31;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AlterPalette.iris.withValues(
          alpha: (isActive ? 0.28 : 0.12) / (i + 1),
        );
      canvas.drawCircle(
        center,
        math.min(radius, size.shortestSide / 2 - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NfcPulsePainter oldDelegate) {
    return oldDelegate.isActive != isActive;
  }
}

class _ExchangeBundle extends StatelessWidget {
  const _ExchangeBundle({required this.profile});

  final NfcProfile profile;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Exchange Bundle',
            subtitle: 'Portfolio, resume, LinkedIn, skills, interests.',
          ),
          const SizedBox(height: 16),
          for (final link in profile.links) _BundleRow(link: link),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in profile.skills.take(5))
                PremiumChip(label: skill),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in profile.interests.take(4))
                PremiumChip(label: interest),
            ],
          ),
        ],
      ),
    );
  }
}

class _BundleRow extends StatelessWidget {
  const _BundleRow({required this.link});

  final NfcProfileLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AlterPalette.iris.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.network, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  link.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStack extends StatelessWidget {
  const _ScoreStack({required this.result});

  final NfcExchangeResult? result;

  @override
  Widget build(BuildContext context) {
    final compatibility = result?.compatibilityScore.round().toString() ?? '--';
    final startup = result?.startupMatch.percentage ?? '--';
    final cofounder = result?.cofounderMatch.percentage ?? '--';
    return Column(
      children: [
        MetricTile(
          label: 'Compatibility',
          value: compatibility == '--' ? compatibility : '$compatibility%',
          icon: LucideIcons.radar,
          accent: AlterPalette.iris,
        ),
        const SizedBox(height: 14),
        MetricTile(
          label: 'Startup Match',
          value: startup,
          icon: LucideIcons.network,
          accent: AlterPalette.cyan,
        ),
        const SizedBox(height: 14),
        MetricTile(
          label: 'Co-founder Match',
          value: cofounder,
          icon: LucideIcons.messages_square,
          accent: AlterPalette.aura,
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassPanel(
        borderOpacity: 0.5,
        child: Row(
          children: [
            Icon(
              isError ? LucideIcons.shield_check : LucideIcons.nfc,
              color: isError ? AlterPalette.danger : AlterPalette.mint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isError
                      ? AlterPalette.danger
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final NfcExchangeResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: result.peerProfile.displayName,
            subtitle:
                '${result.peerProfile.role} - ${result.peerProfile.location}',
            trailing: PremiumChip(
              label: '${result.compatibilityScore.round()}%',
              selected: true,
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 2,
            children: [
              _TermGroup(title: 'Shared Skills', values: result.sharedSkills),
              _TermGroup(
                title: 'Shared Interests',
                values: result.sharedInterests,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Next Moves',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final action in result.recommendedActions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.route,
                    size: 17,
                    color: AlterPalette.iris,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      action,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).moveY(begin: 10, end: 0);
  }
}

class _TermGroup extends StatelessWidget {
  const _TermGroup({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleValues = values.isEmpty ? const ['No direct overlap'] : values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in visibleValues) PremiumChip(label: value),
          ],
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final NfcMatchSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  signal.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumChip(
                label: signal.percentage,
                selected: signal.score >= 70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: signal.score / 100,
              minHeight: 8,
              backgroundColor: AlterPalette.iris.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AlterPalette.iris),
            ),
          ),
          const SizedBox(height: 14),
          for (final reason in signal.reasons.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

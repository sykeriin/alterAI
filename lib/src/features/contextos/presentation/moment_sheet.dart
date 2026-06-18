import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../application/lifeshield_controller.dart';
import '../domain/contextos_models.dart';

/// Opens the system-like Moment Sheet — a quick-capture overlay that runs the
/// full LifeShield pipeline inline, from anywhere in the app.
Future<void> showMomentSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MomentSheet(),
  );
}

class _MomentSheet extends ConsumerStatefulWidget {
  const _MomentSheet();

  @override
  ConsumerState<_MomentSheet> createState() => _MomentSheetState();
}

class _MomentSheetState extends ConsumerState<_MomentSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(lifeShieldControllerProvider);
    final notifier = ref.read(lifeShieldControllerProvider.notifier);
    final analysis = state.analysis;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: (isDark ? AlterPalette.graphite : AlterPalette.white)
              .withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(
              color: AlterPalette.iris.withValues(alpha: 0.25),
              width: 1.3,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AlterPalette.premiumGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.shield,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Drop a moment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Paste a message, link, payment, or install prompt. ALTER checks it '
              'on-device before you act.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              onChanged: notifier.setInput,
              decoration: const InputDecoration(hintText: 'Paste the moment…'),
            ),
            const SizedBox(height: 12),
            if (analysis != null) _MiniVerdict(analysis: analysis),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AlterPalette.premiumGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                      ),
                      icon: Icon(
                        state.isAnalyzing
                            ? LucideIcons.loader
                            : LucideIcons.shield_check,
                        size: 18,
                      ),
                      label: Text(
                        state.isAnalyzing ? 'Checking…' : 'Check moment',
                      ),
                      onPressed: state.isAnalyzing
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              notifier.setSource(MomentSource.shareSheet);
                              notifier.capture();
                            },
                    ),
                  ),
                ),
                if (analysis != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/shield');
                    },
                    child: const Text('Open'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniVerdict extends StatelessWidget {
  const _MiniVerdict({required this.analysis});

  final MomentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = analysis.verdict.color;
    final icon = switch (analysis.verdict) {
      RiskVerdict.dangerous => LucideIcons.octagon_x,
      RiskVerdict.needsVerification => LucideIcons.shield_question_mark,
      RiskVerdict.caution => LucideIcons.triangle_alert,
      RiskVerdict.safe => LucideIcons.shield_check,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.verdict.label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: c,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  analysis.headline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

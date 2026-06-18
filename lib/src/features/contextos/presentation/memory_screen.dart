import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/memory_engine.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _ctrl = TextEditingController();
  String _type = 'domain';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trustedAsync = ref.watch(memoryProvider);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Memory',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sources you trust. ALTER mutes non-critical warnings for these — '
            'but never silences a real scam (OTP, payment, impersonation).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a trusted source',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'domain', label: Text('Domain')),
                    ButtonSegment(value: 'contact', label: Text('Contact')),
                    ButtonSegment(value: 'app', label: Text('App')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: _type == 'domain'
                              ? 'amazon.in'
                              : _type == 'contact'
                              ? 'Mom / +9198…'
                              : 'WhatsApp',
                          prefixIcon: const Icon(LucideIcons.shield_check),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PremiumButton(
                      label: 'Trust',
                      icon: LucideIcons.plus,
                      compact: true,
                      onPressed: () {
                        final v = _ctrl.text.trim();
                        if (v.isEmpty) return;
                        ref.read(memoryProvider.notifier).addTrusted(_type, v);
                        _ctrl.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          trustedAsync.when(
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) =>
                GlassPanel(child: Text('Could not load memory: $e')),
            data: (trusted) => trusted.isEmpty
                ? GlassPanel(
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.brain,
                          size: 40,
                          color: AlterPalette.iris,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No trusted sources yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When LifeShield over-warns you about a safe sender, '
                          'tap “Trust source” — it lands here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final e in trusted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TrustedRow(
                            entity: e,
                            onRemove: () =>
                                ref.read(memoryProvider.notifier).remove(e),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TrustedRow extends StatelessWidget {
  const _TrustedRow({required this.entity, required this.onRemove});

  final TrustedEntity entity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (entity.type) {
      'contact' => LucideIcons.user,
      'app' => LucideIcons.layout_grid,
      _ => LucideIcons.globe,
    };
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AlterPalette.mint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  entity.type,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash_2, size: 16),
            color: AlterPalette.danger.withValues(alpha: 0.7),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

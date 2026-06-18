import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../ui/widgets.dart';
import '../../../data/local/dao_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../application/memory_engine.dart';
import '../../identity/application/identity_engine.dart';
import '../../identity/domain/identity_trait.dart';
import '../../memory/application/memory_review_controller.dart';
import '../../memory/application/memory_store.dart';
import '../../memory/domain/memory_item.dart';
import 'memory_card.dart';

/// Governance, trusted sources, and identity — secondary to the swipe deck.
class MemorySettingsSheet extends ConsumerStatefulWidget {
  const MemorySettingsSheet({super.key});

  @override
  ConsumerState<MemorySettingsSheet> createState() => _MemorySettingsSheetState();
}

class _MemorySettingsSheetState extends ConsumerState<MemorySettingsSheet> {
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
    final governance =
        ref.watch(memoryGovernanceProvider).asData?.value ??
        const MemoryGovernanceSettings();
    final traitsAsync = ref.watch(identityEngineProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: theme.colorScheme.surface,
            child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Memory settings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              traitsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (traits) => traits.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionKicker(
                            title: 'Your profile',
                            subtitle: 'Built from memories you kept.',
                          ),
                          const SizedBox(height: 8),
                          for (final t in traits)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TraitRow(trait: t),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
              _GovernancePanel(
                settings: governance,
                onSave: ref.read(memoryGovernanceProvider.notifier).save,
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trusted sources',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reduce false alarms without silencing real risks.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
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
                      onSelectionChanged: (selection) =>
                          setState(() => _type = selection.first),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            decoration: InputDecoration(
                              hintText: _type == 'domain'
                                  ? 'example.com'
                                  : _type == 'contact'
                                  ? 'Mom or +91...'
                                  : 'WhatsApp',
                              prefixIcon: const Icon(LucideIcons.shield_check),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        LimeButton(
                          label: 'Trust',
                          trailing: LucideIcons.plus,
                          height: 48,
                          onTap: () {
                            final value = _ctrl.text.trim();
                            if (value.isEmpty) return;
                            ref
                                .read(memoryProvider.notifier)
                                .addTrusted(_type, value);
                            _ctrl.clear();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              trustedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load: $e'),
                data: (trusted) => trusted.isEmpty
                    ? const Text('No trusted sources yet.')
                    : Column(
                        children: [
                          for (final entity in trusted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TrustedRow(
                                entity: entity,
                                onRemove: () => ref
                                    .read(memoryProvider.notifier)
                                    .remove(entity),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              OutlineButton2(
                label: 'Purge expired memories',
                onTap: () =>
                    ref.read(memoryStoreProvider.notifier).purgeExpired(),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.trait});

  final IdentityTrait trait;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 16, color: AlterPalette.aura),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trait.dimension,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AlterPalette.iris,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  trait.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${trait.sourceMemoryIds.length} sources',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _GovernancePanel extends StatelessWidget {
  const _GovernancePanel({required this.settings, required this.onSave});

  final MemoryGovernanceSettings settings;
  final ValueChanged<MemoryGovernanceSettings> onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Governance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.defaultRetention,
            decoration: const InputDecoration(labelText: 'Default retention'),
            items: const [
              DropdownMenuItem(
                value: 'ephemeral',
                child: Text('Forget after use'),
              ),
              DropdownMenuItem(
                value: 'session',
                child: Text('Keep for this session'),
              ),
              DropdownMenuItem(
                value: 'expiring',
                child: Text('Keep until expiry'),
              ),
              DropdownMenuItem(value: 'durable', child: Text('Durable memory')),
            ],
            onChanged: (value) {
              if (value != null) {
                onSave(settings.copyWith(defaultRetention: value));
              }
            },
          ),
          _GovernanceSwitch(
            title: 'Confirm durable memories',
            subtitle: 'Facts wait for your swipe before becoming identity.',
            value: settings.durableRequiresConfirmation,
            onChanged: (value) =>
                onSave(settings.copyWith(durableRequiresConfirmation: value)),
          ),
          _GovernanceSwitch(
            title: 'Confirm sensitive memories',
            subtitle: 'Private facts never persist silently.',
            value: settings.sensitiveRequiresConfirmation,
            onChanged: (value) =>
                onSave(settings.copyWith(sensitiveRequiresConfirmation: value)),
          ),
          _GovernanceSwitch(
            title: 'Portable encrypted export',
            subtitle: 'Allow selected memories to move between devices.',
            value: settings.portableExportEnabled,
            onChanged: (value) =>
                onSave(settings.copyWith(portableExportEnabled: value)),
          ),
          Text(
            'Recall budget: ${settings.maxRetrievalChars} characters',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            min: 1000,
            max: 12000,
            divisions: 11,
            value: settings.maxRetrievalChars.clamp(1000, 12000).toDouble(),
            onChanged: (value) =>
                onSave(settings.copyWith(maxRetrievalChars: value.round())),
          ),
        ],
      ),
    );
  }
}

class _GovernanceSwitch extends StatelessWidget {
  const _GovernanceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
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
                Text(entity.type, style: theme.textTheme.labelSmall),
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

/// Browse confirmed memories in a list (secondary to swipe deck).
class MemoryKeptSheet extends ConsumerWidget {
  const MemoryKeptSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final keptAsync = ref.watch(memoryKeptListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: theme.colorScheme.surface,
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kept memories',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: keptAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('No kept memories yet.'))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final m = items[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassPanel(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.content.isNotEmpty
                                          ? m.content
                                          : m.title,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      MemoryCard.kindLabel(m.kind),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    if (m.id != null)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash_2,
                                            size: 16,
                                          ),
                                          onPressed: () => ref
                                              .read(
                                                memoryStoreProvider.notifier,
                                              )
                                              .forget(m.id!),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../domain/entities/alter_models.dart';
import '../../shared/application/alter_data_providers.dart';

class SocialGraphScreen extends ConsumerWidget {
  const SocialGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(socialGraphProvider);
    final theme = Theme.of(context);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      'Social Graph',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Relationship intelligence for warm paths, NFC exchanges, and network compounding.',
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
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: 'Add contact',
                style: IconButton.styleFrom(
                  backgroundColor: AlterPalette.iris,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(LucideIcons.user_plus),
                onPressed: () => _showAddContactDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              GlassPanel(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: context.isCompact ? 280 : 340,
                  child: _GraphView(
                    nodeCount: contacts.asData?.value.length ?? 0,
                  ),
                ),
              ),
              MetricTile(
                label: 'Contacts',
                value: contacts.asData?.value.length.toString() ?? '--',
                icon: LucideIcons.network,
                accent: AlterPalette.iris,
              ),
              MetricTile(
                label: 'Strong ties',
                value: contacts.asData?.value == null
                    ? '--'
                    : contacts.asData!.value
                        .where((c) => c.strength >= 0.6)
                        .length
                        .toString(),
                icon: LucideIcons.zap,
                accent: AlterPalette.cyan,
              ),
              GlassPanel(
                onTap: () => context.go('/nfc'),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AlterPalette.coolGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(LucideIcons.nfc, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NFC Networking',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap exchange with match intelligence.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.route, size: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          contacts.when(
            data: (items) => items.isEmpty
                ? GlassPanel(
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.users,
                          size: 40,
                          color: AlterPalette.iris,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No contacts yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first contact.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumButton(
                          label: 'Add contact',
                          icon: LucideIcons.user_plus,
                          compact: true,
                          onPressed: () => _showAddContactDialog(context, ref),
                        ),
                      ],
                    ),
                  )
                : ResponsiveGrid(
                    mediumColumns: 2,
                    expandedColumns: 2,
                    children: [
                      for (final contact in items)
                        _ContactCard(
                          contact: contact,
                          onDelete: () =>
                              _deleteContact(context, ref, contact.name),
                        ),
                    ],
                  ),
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 170,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Text('Unable to load social graph: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddContactDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (result == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('social_contacts').insert({
        'user_id': userId,
        'name': result['name'],
        'context': result['context'],
        'strength': result['strength'],
        'tags': result['tags'],
      });
      ref.invalidate(socialGraphProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add contact: $e')));
      }
    }
  }

  Future<void> _deleteContact(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('social_contacts')
        .delete()
        .eq('user_id', userId)
        .eq('name', name);
    ref.invalidate(socialGraphProvider);
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  double _strength = 0.5;
  final _tags = <String>[];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contextCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Contact',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(LucideIcons.user),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextCtrl,
              decoration: const InputDecoration(
                labelText: 'Role / context',
                prefixIcon: Icon(LucideIcons.briefcase),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Connection strength',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${(_strength * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AlterPalette.iris,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: _strength,
              onChanged: (v) => setState(() => _strength = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      prefixIcon: Icon(LucideIcons.tag),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AlterPalette.iris,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _addTag(_tagCtrl.text),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    Chip(
                      label: Text(tag),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                      deleteIcon: const Icon(LucideIcons.x, size: 14),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AlterPalette.iris,
                    ),
                    onPressed: _submit,
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() => _tags.add(trimmed));
    _tagCtrl.clear();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, {
      'name': name,
      'context': _contextCtrl.text.trim(),
      'strength': _strength,
      'tags': List<String>.from(_tags),
    });
  }
}

class _GraphView extends StatelessWidget {
  const _GraphView({required this.nodeCount});

  final int nodeCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphPainter(nodeCount: nodeCount),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AlterPalette.coolGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 74,
            height: 74,
            child: Icon(LucideIcons.user, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.nodeCount});

  /// One orbiting node per real contact (capped) so the graphic reflects the
  /// actual network rather than a fixed decorative count.
  final int nodeCount;

  @override
  void paint(Canvas canvas, Size size) {
    final count = nodeCount.clamp(0, 12);
    if (count == 0) return; // no contacts yet — just the centre node (child)

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final nodes = List<Offset>.generate(count, (index) {
      final angle = (math.pi * 2 / count) * index - math.pi / 2;
      final jitter = index.isEven ? 0.82 : 1.08;
      return Offset(
        center.dx + math.cos(angle) * radius * jitter,
        center.dy + math.sin(angle) * radius * jitter,
      );
    });

    final linePaint = Paint()
      ..color = AlterPalette.iris.withValues(alpha: 0.2)
      ..strokeWidth = 1.2;

    for (final node in nodes) {
      canvas.drawLine(center, node, linePaint);
    }
    if (nodes.length >= 4) {
      for (var i = 0; i < nodes.length; i += 2) {
        canvas.drawLine(nodes[i], nodes[(i + 3) % nodes.length], linePaint);
      }
    }
    for (final node in nodes) {
      canvas.drawCircle(
        node,
        10,
        Paint()..color = AlterPalette.iris.withValues(alpha: 0.14),
      );
      canvas.drawCircle(node, 4.5, Paint()..color = AlterPalette.iris);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.nodeCount != nodeCount;
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onDelete});

  final SocialContact contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AlterPalette.iris.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(LucideIcons.user, color: AlterPalette.iris),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      contact.context,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.56,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PremiumChip(
                label: '${(contact.strength * 100).round()}%',
                selected: true,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(LucideIcons.trash_2, size: 16),
                color: AlterPalette.danger.withValues(alpha: 0.7),
                tooltip: 'Remove',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in contact.tags) PremiumChip(label: tag)],
          ),
        ],
      ),
    );
  }
}

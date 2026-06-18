import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../../memory/domain/memory_item.dart';

/// Human-first card for inferred memory facts (not log rows).
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    required this.item,
    this.onEdit,
    super.key,
  });

  final MemoryItem item;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final fact = item.content.isNotEmpty ? item.content : item.title;
    final category = item.title.isNotEmpty && item.content.isNotEmpty
        ? item.title
        : _kindLabel(item.kind);

    final cardColor = isLight
        ? const Color(0xFFF8F6FC)
        : const Color(0xFF1A1528);
    final borderColor = isLight
        ? const Color(0xFFD8D2E8)
        : AppColors.white(0.18);

    return GlassCard(
      padding: const EdgeInsets.all(22),
      color: cardColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AlterPalette.iris,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fact,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: isLight ? const Color(0xFF121018) : AppColors.white(0.95),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip(label: _kindLabel(item.kind), selected: true),
              if (item.sensitivity != MemorySensitivity.normal)
                PillChip(
                  label: item.sensitivity.name,
                  selected: true,
                ),
              if (!item.confirmed)
                PillChip(label: 'Needs review', selected: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _provenanceLabel(item.provenance),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ALTER is ~${(item.confidence * 100).round()}% sure',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  static String kindLabel(MemoryKind kind) => _kindLabel(kind);

  static String _kindLabel(MemoryKind kind) => switch (kind) {
        MemoryKind.preference => 'Preference',
        MemoryKind.relationship => 'Relationship',
        MemoryKind.commitment => 'Commitment',
        MemoryKind.goal => 'Goal',
        MemoryKind.decision => 'Decision',
        MemoryKind.routine => 'Routine',
        MemoryKind.skill => 'Skill',
        MemoryKind.event => 'Event',
        MemoryKind.communicationStyle => 'Communication',
        MemoryKind.observation => 'Observation',
      };

  static String _provenanceLabel(String provenance) {
    final lower = provenance.toLowerCase();
    if (lower.startsWith('voice')) return 'From voice';
    if (lower.contains('lifeshield') || lower.contains('shield')) {
      return 'From LifeShield';
    }
    if (lower.contains('onboarding')) return 'From onboarding';
    if (lower.contains('moment')) return 'From a captured moment';
    if (provenance.trim().isEmpty) return 'From your interactions';
    return 'From ${provenance.split(':').first}';
  }
}

/// Swipe labels shown while dragging — must not steal gestures from the card.
class MemorySwipeOverlay extends StatelessWidget {
  const MemorySwipeOverlay({
    required this.keepOpacity,
    required this.forgetOpacity,
    super.key,
  });

  final double keepOpacity;
  final double forgetOpacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          if (keepOpacity > 0)
            Positioned(
              left: 24,
              top: 24,
              child: Opacity(
                opacity: keepOpacity.clamp(0, 1),
                child: _SwipeLabel(
                  label: 'KEEP',
                  color: AlterPalette.mint,
                  icon: LucideIcons.check,
                ),
              ),
            ),
          if (forgetOpacity > 0)
            Positioned(
              right: 24,
              top: 24,
              child: Opacity(
                opacity: forgetOpacity.clamp(0, 1),
                child: _SwipeLabel(
                  label: 'FORGET',
                  color: AlterPalette.danger,
                  icon: LucideIcons.x,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeLabel extends StatelessWidget {
  const _SwipeLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        color: color.withValues(alpha: 0.18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

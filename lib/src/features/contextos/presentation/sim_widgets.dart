import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';

/// A labeled 0..1 metric bar shared by the simulation views.
class SimMetricBar extends StatelessWidget {
  const SimMetricBar({
    required this.label,
    required this.value,
    required this.color,
    this.invertGood = false,
    super.key,
  });

  final String label;
  final double value;
  final Color color;

  /// When true (e.g. risk/regret), higher = worse, so it tints toward danger.
  final bool invertGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = value.clamp(0, 1).toDouble();
    final c = invertGood
        ? (shown >= 0.66
              ? AlterPalette.danger
              : shown >= 0.33
              ? AlterPalette.amber
              : AlterPalette.mint)
        : color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: shown,
                minHeight: 7,
                backgroundColor: c.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(shown * 100).round()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small colored chip used for path types and recommendations.
class SimTag extends StatelessWidget {
  const SimTag({
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.9 : 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

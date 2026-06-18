import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// @deprecated Use [StatCard] from `ui/widgets.dart` directly.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      label: label,
      value: value,
      icon: icon,
      detail: detail,
      accent: accent ?? AppColors.purple,
    );
  }
}

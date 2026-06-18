import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// @deprecated Use [LimeButton], [PillChip], [SectionKicker] from `ui/widgets.dart`.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return LimeButton(
        label: label,
        onTap: onPressed,
        height: compact ? 48 : 60,
        trailing: icon,
      );
    }
    return LimeButton(
      label: label,
      onTap: onPressed,
      height: compact ? 48 : 60,
      trailing: null,
    );
  }
}

class PremiumChip extends StatelessWidget {
  const PremiumChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PillChip(label: label, selected: selected, onTap: onTap);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionKicker(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

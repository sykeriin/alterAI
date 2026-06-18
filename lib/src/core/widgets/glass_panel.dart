import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../theme/alter_palette.dart';

/// @deprecated Use [GlassCard] from `ui/widgets.dart` directly.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.borderOpacity = 0.34,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      radius: radius,
      onTap: onTap,
      borderColor: AppColors.white(borderOpacity * 0.3),
      child: child,
    );
  }
}

class GradientBorderPanel extends StatelessWidget {
  const GradientBorderPanel({
    required this.child,
    this.padding = const EdgeInsets.all(1),
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AlterPalette.premiumGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: GlassCard(
          radius: radius - 1,
          padding: EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

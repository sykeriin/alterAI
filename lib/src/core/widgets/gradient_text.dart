import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// @deprecated Use [AppText.display] from `ui/theme.dart` directly.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    this.style,
    this.gradient,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style;
    final size = base?.fontSize ?? 13;
    final weight = base?.fontWeight ?? FontWeight.w600;
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: AppText.display(
        size,
        weight: weight,
        letterSpacing: base?.letterSpacing ?? 2.0,
        color: base?.color ?? AppColors.white(0.92),
        height: base?.height ?? 1.08,
      ),
    );
  }
}

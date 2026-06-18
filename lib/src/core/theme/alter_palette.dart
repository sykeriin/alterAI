import 'package:flutter/material.dart';

/// Palette tokens aligned with [AppColors] hex values for visual consistency.
/// Domain enums use these as const; UI code should prefer [AppColors] directly.
class AlterPalette {
  const AlterPalette._();

  static const snow = Color(0xFFF8F7FF);
  static const white = Color(0xFFFFFFFF);
  static const mist = Color(0xFFE8E7F5);
  static const ink = Color(0xFF0A0810);
  static const graphite = Color(0xFF0D0A16);
  static const slate = Color(0xFF62657A);
  static const iris = Color(0xFF7C5CFF);
  static const violet = Color(0xFF9B6BFF);
  static const aura = Color(0xFFFF6BD0);
  static const cyan = Color(0xFF5BE0FF);
  static const mint = Color(0xFF38E8A0);
  static const amber = Color(0xFFFFC861);
  static const danger = Color(0xFFFF8A8A);

  static const premiumGradient = LinearGradient(
    colors: [iris, violet, aura],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const coolGradient = LinearGradient(
    colors: [cyan, iris],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

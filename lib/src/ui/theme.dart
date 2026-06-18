import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global light/dark theme switch. Flip [isLight] and the whole app rebuilds
/// (see the ValueListenableBuilder in main.dart).
class AlterUiTheme {
  static final ValueNotifier<bool> isLight = ValueNotifier<bool>(false);
  static bool get light => isLight.value;

  static Future<void> setLight(bool v) async {
    if (isLight.value == v) return;
    isLight.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alter_theme_light', v);
  }

  static Future<void> toggle() => setLight(!isLight.value);
}

/// Alter design tokens — colors and typography.
class AppColors {
  // Base (kept const: used in const gradient lists + as text color on bright
  // lime buttons, which stay dark in BOTH themes).
  static const bg = Color(0xFF0A0810);
  static const ink = Color(0xFF120E1C);

  // Theme-aware neutrals.
  static Color get bgRaised =>
      AlterUiTheme.light ? const Color(0xFFFFFFFF) : const Color(0xFF0D0A16);
  static Color get surfaceSolid =>
      AlterUiTheme.light ? const Color(0xFFFFFFFF) : const Color(0xFF0D0A16);
  static Color get screenBase =>
      AlterUiTheme.light ? const Color(0xFFEAE3F4) : bg;
  static Color get navBg =>
      AlterUiTheme.light ? const Color(0xFFFFFFFF) : const Color(0xFF14101C);
  /// White pill surface (e.g. "Ask Alter how") — flips to ink on light.
  static Color get pill =>
      AlterUiTheme.light ? const Color(0xFF18131F) : Colors.white;
  static Color get pillInk =>
      AlterUiTheme.light ? const Color(0xFFF5F2FB) : const Color(0xFF0A0810);

  /// Theme-aware screen gradient stops (dark palette in, light palette out).
  static List<Color> screenGradient(List<Color> darkStops) {
    if (!AlterUiTheme.light) return darkStops;
    return [
      for (var i = 0; i < darkStops.length; i++)
        i == 0
            ? Color.lerp(darkStops[i], Colors.white, 0.82)!
            : (i == darkStops.length - 1
                ? const Color(0xFFEAE3F4)
                : const Color(0xFFF2EEFB)),
    ];
  }

  // Accents
  static const lime = Color(0xFFCDF74D);
  static const limeDeep = Color(0xFFA6D63A);
  static const purple = Color(0xFF7C5CFF);
  static const purpleLight = Color(0xFF9B6BFF);
  static const purpleDeep = Color(0xFF5A2DB0);
  static const cyan = Color(0xFF5BE0FF);
  static const cyanDeep = Color(0xFF2D7AD0);
  static const orange = Color(0xFFFF8A3C);
  static const orangeDeep = Color(0xFFD14D1A);
  static const green = Color(0xFF38E8A0);
  static const greenDeep = Color(0xFF11A06A);
  static const pink = Color(0xFFFF6BD0);
  static const pinkDeep = Color(0xFFC02D9B);
  static const danger = Color(0xFFFF8A8A);

  // Foreground neutral — drives ALL text + translucent "glass" surfaces.
  // Flips from white (dark theme) to near-black indigo (light theme), so every
  // rgba(white, a) call themes correctly while preserving its alpha.
  static Color get _fg => AlterUiTheme.light ? const Color(0xFF18131F) : Colors.white;
  static Color white(double o) => _fg.withValues(alpha: o);
  static Color get glass => _fg.withValues(alpha: 0.05);
  static Color get glassBorder => _fg.withValues(alpha: 0.10);
}

class AppText {
  /// Space Grotesk — display / headings.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.08,
    double letterSpacing = -0.4,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.white(0.92),
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  /// Manrope — body / UI.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.4,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.white(0.88),
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Uppercase eyebrow / kicker label.
  static TextStyle kicker(Color color, {double size = 11}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.8,
      );
}

ThemeData buildAlterTheme(bool light) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
  );
  final fg = light ? const Color(0xFF18131F) : Colors.white;
  final screenBase = light ? const Color(0xFFEAE3F4) : AppColors.bg;
  final surface = light ? const Color(0xFFFFFFFF) : const Color(0xFF0D0A16);
  return base.copyWith(
    scaffoldBackgroundColor: screenBase,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.lime,
      secondary: AppColors.purpleLight,
      surface: surface,
      onSurface: fg,
    ),
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: fg,
      displayColor: fg,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Rebuilds [child] whenever light/dark mode changes.
class AlterThemeBuilder extends StatelessWidget {
  const AlterThemeBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, bool light) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlterUiTheme.isLight,
      builder: (context, light, _) => builder(context, light),
    );
  }
}

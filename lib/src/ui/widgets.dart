import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alter/src/core/widgets/alter_logo.dart';
import 'package:alter/src/ui/theme.dart';

/// Default radial gradient stops for all ALTER pages.
const kAlterPageBg = [
  Color(0xFF241A40),
  Color(0xFF120E1C),
  AppColors.bg,
];

/// ALTER icon mark used throughout the app.
class StarMark extends StatelessWidget {
  final double size;
  final Color color;
  const StarMark({super.key, this.size = 24, this.color = AppColors.lime});

  @override
  Widget build(BuildContext context) {
    return AlterLogo(
      showWordmark: false,
      width: size,
      height: size,
      color: color,
    );
  }
}

/// A soft blurred gradient orb used in backgrounds.
class Orb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final double blur;
  final Alignment focal;
  const Orb({
    super.key,
    required this.size,
    required this.colors,
    this.blur = 40,
    this.focal = const Alignment(-0.3, -0.3),
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: focal,
            radius: 0.75,
            colors: [...colors, Colors.transparent],
            stops: _stops(colors.length + 1),
          ),
        ),
      ),
    );
  }

  List<double> _stops(int n) {
    if (n == 3) return const [0.0, 0.55, 0.95];
    if (n == 2) return const [0.0, 0.95];
    return List.generate(n, (i) => i / (n - 1));
  }
}

/// Full-screen gradient background with optional positioned orbs.
class GradientScaffold extends StatelessWidget {
  final List<Color> bgColors;
  final List<double>? bgStops;
  final Alignment bgCenter;
  final List<Widget> orbs;
  final Widget child;
  final bool safeTop;

  const GradientScaffold({
    super.key,
    required this.child,
    this.bgColors = const [Color(0xFF2A1F4A), AppColors.bg],
    this.bgStops,
    this.bgCenter = const Alignment(-0.6, -0.9),
    this.orbs = const [],
    this.safeTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlterUiTheme.isLight,
      builder: (context, light, __) {
        final cols = light
            ? [
                for (var i = 0; i < bgColors.length; i++)
                  i == 0
                      ? Color.lerp(bgColors[i], Colors.white, 0.82)!
                      : (i == bgColors.length - 1
                          ? const Color(0xFFEAE3F4)
                          : const Color(0xFFF2EEFB))
              ]
            : bgColors;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: bgCenter,
              radius: 1.2,
              colors: cols,
              stops: (bgStops == null || bgStops!.isEmpty)
                  ? _evenStops(cols.length)
                  : bgStops,
            ),
          ),
          child: Stack(
            children: [
              ...orbs,
              Positioned.fill(child: child),
            ],
          ),
        );
      },
    );
  }

  List<double> _evenStops(int n) {
    if (n == 3) return const [0.0, 0.5, 1.0];
    return List.generate(n, (i) => i / (n - 1));
  }
}

/// Positioned orb helper for backgrounds.
class PositionedOrb extends StatelessWidget {
  final double? top, left, right, bottom;
  final Orb orb;
  const PositionedOrb({
    super.key,
    required this.orb,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: orb,
    );
  }
}

/// A pill chip (selectable).
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const PillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : AppColors.white(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.lime : AppColors.white(0.16),
          ),
        ),
        child: Text(
          label,
          style: AppText.body(
            14.5,
            weight: FontWeight.w600,
            color: selected ? AppColors.bg : AppColors.white(0.92),
          ),
        ),
      ),
    );
  }
}

/// Small static info chip.
class TagChip extends StatelessWidget {
  final String label;
  const TagChip(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white(0.16)),
      ),
      child: Text(label,
          style: AppText.body(12.5,
              weight: FontWeight.w600, color: AppColors.white(0.85))),
    );
  }
}

/// Frosted-glass surface card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.white(0.05),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.white(0.10)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Top header row for primary screens: gear (left), title (center), avatar (right).
class PrimaryHeader extends StatelessWidget {
  final String title;
  final bool showAvatar;
  final bool starTitle;
  final VoidCallback? onGear;
  final VoidCallback? onAvatar;
  const PrimaryHeader({
    super.key,
    required this.title,
    this.showAvatar = true,
    this.starTitle = false,
    this.onGear,
    this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GearButton(onTap: onGear),
        if (starTitle)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const StarMark(size: 16),
            const SizedBox(width: 7),
            Text(title,
                style: AppText.display(13,
                    weight: FontWeight.w600, letterSpacing: 2.3)),
          ])
        else
          Text(title,
              style: AppText.display(13,
                  weight: FontWeight.w600, letterSpacing: 2.3)),
        if (showAvatar)
          GestureDetector(
            onTap: onAvatar,
            child: const AvatarDot(),
          )
        else
          const SizedBox(width: 42),
      ],
    );
  }
}

class GearButton extends StatelessWidget {
  final VoidCallback? onTap;
  const GearButton({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white(0.12)),
        ),
        child: Icon(Icons.settings_outlined, size: 21, color: AppColors.white(0.9)),
      ),
    );
  }
}

class BackPill extends StatelessWidget {
  final VoidCallback? onTap;
  const BackPill({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            if (context.canPop()) {
              context.pop();
            } else {
              Navigator.maybePop(context);
            }
          },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white(0.14)),
        ),
        child: Icon(Icons.arrow_back, size: 20, color: AppColors.white(0.9)),
      ),
    );
  }
}

class AvatarDot extends StatelessWidget {
  final double size;
  const AvatarDot({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.purpleLight, AppColors.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.white(0.18)),
      ),
      child: Text('A',
          style: AppText.display(size * 0.4, weight: FontWeight.w700)),
    );
  }
}

/// Primary filled lime button.
class LimeButton extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final VoidCallback? onTap;
  final double height;
  const LimeButton({
    super.key,
    required this.label,
    this.trailing = Icons.arrow_forward,
    this.onTap,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(height / 2.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: AppText.body(16,
                    weight: FontWeight.w800, color: AppColors.bg)),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Icon(trailing, color: AppColors.bg, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Secondary outline button.
class OutlineButton2 extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  const OutlineButton2(
      {super.key, required this.label, this.onTap, this.height = 54});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white(0.06),
          borderRadius: BorderRadius.circular(height / 2.2),
          border: Border.all(color: AppColors.white(0.2)),
        ),
        child: Text(label,
            style: AppText.body(15, weight: FontWeight.w600)),
      ),
    );
  }
}

/// Tab / shell-root page layout: gradient + optional header + scrollable body.
class AlterPageLayout extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final List<Color> bgColors;
  final Alignment bgCenter;
  final double bottomInset;
  final bool scrollable;
  final List<Widget> orbs;
  final EdgeInsetsGeometry? padding;

  const AlterPageLayout({
    super.key,
    required this.child,
    this.header,
    this.bgColors = kAlterPageBg,
    this.bgCenter = const Alignment(0.6, -1.0),
    this.bottomInset = 104,
    this.scrollable = true,
    this.orbs = const [],
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final pagePadding = padding ??
        EdgeInsets.fromLTRB(22, 10, 22, bottomInset);

    final body = scrollable
        ? ListView(
            padding: pagePadding,
            children: [
              if (header != null) ...[header!, const SizedBox(height: 18)],
              child,
            ],
          )
        : Padding(
            padding: pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header!, const SizedBox(height: 18)],
                Expanded(child: child),
              ],
            ),
          );

    return GradientScaffold(
      bgColors: bgColors,
      bgCenter: bgCenter,
      orbs: orbs,
      child: SafeArea(
        bottom: false,
        child: body,
      ),
    );
  }
}

/// Full-screen page with [Scaffold] — for standalone pushed routes.
class AlterPageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final List<Color> bgColors;
  final double bottomInset;
  final bool scrollable;

  const AlterPageScaffold({
    super.key,
    required this.child,
    this.header,
    this.bgColors = kAlterPageBg,
    this.bottomInset = 24,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AlterPageLayout(
        bgColors: bgColors,
        bottomInset: bottomInset,
        scrollable: scrollable,
        header: header,
        child: child,
      ),
    );
  }
}

/// Shared deep-screen scaffold (back · title · optional subtitle).
class DeepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Color> bg;
  final Alignment bgCenter;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final double bottomInset;

  const DeepScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.bg = kAlterPageBg,
    this.bgCenter = const Alignment(0.0, -1.0),
    this.contentPadding = const EdgeInsets.fromLTRB(22, 16, 22, 24),
    this.bottomInset = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: bg,
        bgCenter: bgCenter,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const BackPill(),
                        Text(title,
                            style: AppText.display(13,
                                weight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: AppColors.white(0.92))),
                        const SizedBox(width: 42),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 10),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: AppText.body(14,
                              color: AppColors.white(0.55), height: 1.4)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    16,
                    22,
                    24 + bottomInset,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shell-root page header: gear · uppercase title · avatar, optional subtitle.
class ShellPageHeader extends StatelessWidget {
  const ShellPageHeader({
    required this.title,
    this.subtitle,
    this.onGear,
    this.showAvatar = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onGear;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrimaryHeader(
          title: title.toUpperCase(),
          showAvatar: showAvatar,
          onGear: onGear,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!,
              style: AppText.body(14,
                  color: AppColors.white(0.55), height: 1.4)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Stat metric card — legacy replacement for MetricTile.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.accent = AppColors.purple,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome, size: 16, color: accent.withValues(alpha: 0.76)),
            ],
          ),
          const SizedBox(height: 18),
          Text(value, style: AppText.display(24, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: AppText.body(13,
                  weight: FontWeight.w700, color: AppColors.white(0.66))),
          if (detail != null) ...[
            const SizedBox(height: 10),
            Text(detail!,
                style: AppText.body(12, color: AppColors.white(0.55), height: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// Section label row — legacy replacement for SectionHeader.
class SectionKicker extends StatelessWidget {
  const SectionKicker({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: AppText.kicker(AppColors.white(0.72))),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    style: AppText.body(14,
                        color: AppColors.white(0.55), height: 1.35)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing!,
        ],
      ],
    );
  }
}

/// Empty state when Alter has not inferred anything yet.
class InferringEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const InferringEmptyState({
    super.key,
    this.title = 'Still inferring…',
    this.subtitle =
        'Nothing observed yet — talk to Alter, scan with Lens, or connect contacts.',
    this.icon = Icons.auto_awesome_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.lime.withValues(alpha: 0.85)),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.display(20, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.white(0.55), height: 1.5)),
        ],
      ),
    );
  }
}

enum VoiceEqualizerMode { idle, listening, speaking }

/// Rainbow gradient audio equalizer — centered vertical bars with wave peaks.
class RainbowEqualizer extends StatelessWidget {
  final VoiceEqualizerMode mode;
  final Animation<double> animation;
  final int barCount;

  const RainbowEqualizer({
    super.key,
    required this.mode,
    required this.animation,
    this.barCount = 35,
  });

  static Color _rainbowAt(double t) {
    final stops = <(double, Color)>[
      (0.00, AppColors.lime),
      (0.16, AppColors.green),
      (0.34, AppColors.cyan),
      (0.52, AppColors.cyanDeep),
      (0.68, AppColors.purple),
      (0.84, AppColors.purpleLight),
      (1.00, AppColors.pink),
    ];
    t = t.clamp(0.0, 1.0);
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (t >= a.$1 && t <= b.$1) {
        final f = (t - a.$1) / (b.$1 - a.$1);
        return Color.lerp(a.$2, b.$2, f)!;
      }
    }
    return AppColors.pink;
  }

  /// Static wave envelope — three peaks (tall · medium · tall) like a spectrum.
  static double _envelope(int i, int n) {
    if (n <= 1) return 1;
    final x = i / (n - 1);
    double peak(double center, double width, double height) {
      final d = (x - center) / width;
      return height * (1 / (1 + d * d * 12));
    }
    return (0.10 +
            peak(0.14, 0.11, 1.0) +
            peak(0.48, 0.10, 0.72) +
            peak(0.84, 0.11, 0.95))
        .clamp(0.12, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        const maxBarHeight = 72.0;
        const barWidth = 4.0;
        const gap = 3.0;
        final t = animation.value;

        return SizedBox(
          height: maxBarHeight + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final phase = (i % 7) / 7;
              final ripple = (0.5 +
                  0.5 *
                      (1 - 2 * ((t + phase) % 1.0 - 0.5).abs()));
              final env = _envelope(i, barCount);
              final amp = switch (mode) {
                VoiceEqualizerMode.idle => env * (0.22 + ripple * 0.10),
                VoiceEqualizerMode.listening => env * (0.45 + ripple * 0.50),
                VoiceEqualizerMode.speaking => env * (0.50 + ripple * 0.50),
              };
              final h = maxBarHeight * amp;
              final color = _rainbowAt(i / (barCount - 1));
              return Container(
                width: barWidth,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: gap / 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barWidth),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme.dart';

/// The 4-point "star" mark used throughout Alter.
class StarMark extends StatelessWidget {
  final double size;
  final Color color;
  const StarMark({super.key, this.size = 24, this.color = AppColors.lime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(color)),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Path();
    // A 4-point concave star (matches the CSS path 12 0 -> curves through midpoints).
    p.moveTo(w * 0.5, 0);
    p.cubicTo(w * 0.5, h * 0.25, w * 0.5, h * 0.25, w, h * 0.5);
    p.cubicTo(w * 0.5, h * 0.75, w * 0.5, h * 0.75, w * 0.5, h);
    p.cubicTo(w * 0.5, h * 0.75, w * 0.5, h * 0.75, 0, h * 0.5);
    p.cubicTo(w * 0.5, h * 0.25, w * 0.5, h * 0.25, w * 0.5, 0);
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
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
  final List<Alignment>? bgStops;
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
    // In light mode, keep each screen's hue (first stop, lightened) and swap the
    // dark mid/base stops for light neutrals — auto-themes every screen.
    final cols = AlterTheme.light
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
          stops: bgStops != null ? null : _evenStops(cols.length),
        ),
      ),
      child: Stack(
        children: [
          ...orbs,
          Positioned.fill(child: child),
        ],
      ),
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
            color: selected ? AppColors.bg : Colors.white,
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
        child: const Icon(Icons.settings_outlined, size: 21, color: Colors.white),
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
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white(0.14)),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
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

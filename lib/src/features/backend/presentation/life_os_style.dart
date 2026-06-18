import 'package:flutter/material.dart';

// ALTER Standalone palette (from the HTML mockup).
const lBg = Color(0xFF0A0810);
const lPanel = Color(0xFF15101F);
const lLime = Color(0xFFCDF74D);
const lCyan = Color(0xFF5BE0FF);
const lPurple = Color(0xFF9B6BFF);
const lPink = Color(0xFFFF6BD0);
const lOrange = Color(0xFFFF8A3C);
const lGreen = Color(0xFF38E8A0);
const lTextHi = Color(0xFFF1EDFA);
const lTextLo = Color(0xFF9A93AD);

/// Dark radial scaffold matching the mockup. Scrolls; leaves room for the nav.
class LifeOsScaffold extends StatelessWidget {
  const LifeOsScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.85),
          radius: 1.3,
          colors: [Color(0xFF1B1330), lBg],
          stops: [0, 0.7],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18, 14, 18, 104 + bottom),
          child: child,
        ),
      ),
    );
  }
}

class LifeOsHeader extends StatelessWidget {
  const LifeOsHeader({
    required this.kicker,
    required this.title,
    this.accent = lLime,
    this.trailing,
    super.key,
  });

  final String kicker;
  final String title;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 27,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class LifeCard extends StatelessWidget {
  const LifeCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: lPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (accent ?? Colors.white).withValues(alpha: accent != null ? 0.3 : 0.07),
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Lime gradient pill, the mockup's signature accent button/badge.
class LimePill extends StatelessWidget {
  const LimePill({
    required this.label,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [lLime, Color(0xFFA6D63A)]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(color: lLime.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: const Color(0xFF14110A)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF14110A),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular match/score ring used by opportunity/future cards.
class ScoreRing extends StatelessWidget {
  const ScoreRing({required this.value, required this.color, this.size = 46, super.key});

  final double value; // 0..1
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${(value * 100).round()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

List<String> lStrings(Object? v) => v is List
    ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
    : const [];

double lDouble(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

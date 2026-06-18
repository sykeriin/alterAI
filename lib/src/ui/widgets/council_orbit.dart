import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:alter/src/features/council/application/five_persona_council.dart';
import 'package:alter/src/ui/theme.dart';

const _personaColors = {
  AlterPersona.presentSelf: AppColors.lime,
  AlterPersona.futureSelf: AppColors.purpleLight,
  AlterPersona.realist: AppColors.cyan,
  AlterPersona.strategist: AppColors.orange,
  AlterPersona.valuesSelf: AppColors.pink,
};

const _shortLabels = {
  AlterPersona.presentSelf: 'Now',
  AlterPersona.futureSelf: 'Future',
  AlterPersona.realist: 'Realist',
  AlterPersona.strategist: 'Strategy',
  AlterPersona.valuesSelf: 'Values',
};

/// Five personas orbiting the user (sun) — always-on council visualization.
class CouncilOrbit extends StatefulWidget {
  const CouncilOrbit({
    super.key,
    this.compact = false,
    this.onConvene,
    this.onPersonaTap,
    this.userInitial = 'Y',
  });

  final bool compact;
  final VoidCallback? onConvene;
  final void Function(AlterPersona persona)? onPersonaTap;
  final String userInitial;

  @override
  State<CouncilOrbit> createState() => _CouncilOrbitState();
}

class _CouncilOrbitState extends State<CouncilOrbit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _orbit = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() {
        _orbit = (elapsed.inMilliseconds / 24000) % 1.0;
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 140.0 : 220.0;
    final sun = widget.compact ? 36.0 : 52.0;
    final planet = widget.compact ? 22.0 : 28.0;
    final personas = AlterPersona.values;

    return SizedBox(
      height: size,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white(0.08)),
            ),
          ),
          GestureDetector(
            onTap: widget.onConvene,
            child: Container(
              width: sun,
              height: sun,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.lime, AppColors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.35),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Text(
                widget.userInitial,
                style: AppText.display(
                  widget.compact ? 16 : 22,
                  weight: FontWeight.w700,
                  color: AppColors.bg,
                ),
              ),
            ),
          ),
          ...List.generate(personas.length, (i) {
            final angle = (_orbit * 2 * math.pi) +
                (i * 2 * math.pi / personas.length);
            final radius = size * 0.38;
            final dx = radius * math.cos(angle);
            final dy = radius * math.sin(angle);
            final p = personas[i];
            final color = _personaColors[p] ?? AppColors.purple;
            return Transform.translate(
              offset: Offset(dx, dy),
              child: GestureDetector(
                onTap: () => widget.onPersonaTap?.call(p),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: planet,
                      height: planet,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.85),
                        border: Border.all(color: AppColors.white(0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        _shortLabels[p] ?? p.label,
                        style: AppText.body(9, color: AppColors.white(0.55)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

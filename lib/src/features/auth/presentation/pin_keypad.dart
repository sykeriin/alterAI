import 'package:flutter/material.dart';

import '../../../ui/theme.dart';

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.slots = 4,
  });

  final int filled;
  final int slots;

  @override
  Widget build(BuildContext context) {
    final count = filled > slots ? filled : slots;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 14 : 12,
            height: active ? 14 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.lime : AppColors.white(0.12),
              border: Border.all(
                color: active ? AppColors.lime : AppColors.white(0.22),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.showBiometric = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool showBiometric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _Key(
                          label: d,
                          onTap: () => onDigit(d),
                        ),
                      ))
                  .toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showBiometric && onBiometric != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _Key(
                  icon: Icons.fingerprint,
                  onTap: onBiometric!,
                ),
              )
            else
              const SizedBox(width: 88, height: 72),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _Key(label: '0', onTap: () => onDigit('0')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white(0.12)),
          ),
          child: icon != null
              ? Icon(icon, color: AppColors.white(0.75), size: 26)
              : Text(
                  label!,
                  style: AppText.display(26, weight: FontWeight.w500),
                ),
        ),
      ),
    );
  }
}

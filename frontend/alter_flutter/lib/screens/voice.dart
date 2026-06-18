import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'main_shell.dart';
import 'deep.dart';

enum VoiceMode { idle, listening, speaking }

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  VoiceMode mode = VoiceMode.idle;
  late final AnimationController _breathe = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat(reverse: true);
  late final AnimationController _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  late final AnimationController _wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    _ring.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _cycle() {
    setState(() {
      mode = switch (mode) {
        VoiceMode.idle => VoiceMode.listening,
        VoiceMode.listening => VoiceMode.speaking,
        VoiceMode.speaking => VoiceMode.idle,
      };
    });
  }

  String get _label => switch (mode) {
        VoiceMode.listening => 'Listening…',
        VoiceMode.speaking => 'Alter is responding',
        VoiceMode.idle => 'Tap to speak, or say "Hey Alter"',
      };

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final voiceBg = AlterTheme.light
        ? const [Color(0xFFECE8F6), Color(0xFFF4F1FB), Color(0xFFEEF0F8)]
        : const [Color(0xFF1A1430), Color(0xFF0D0A16), Color(0xFF060409)];
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 1.3,
          colors: voiceBg,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Stack(children: [
          // Top controls
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GearButton(onTap: shell.openSettings),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const StarMark(size: 15),
                  const SizedBox(width: 7),
                  Text('ALTER',
                      style: AppText.display(12,
                          weight: FontWeight.w600, letterSpacing: 2.5)),
                ]),
                // Alter Lens (camera)
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lime.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.lime.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 20, color: AppColors.lime),
                  ),
                ),
              ],
            ),
          ),
          // Orb + animation
          Align(
            alignment: const Alignment(0, -0.25),
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                if (mode == VoiceMode.listening) ..._rings(),
                _orb(),
              ]),
            ),
          ),
          // Label
          Align(
            alignment: const Alignment(0, 0.18),
            child: Text(_label,
                style: AppText.display(19,
                    weight: FontWeight.w500, color: AppColors.white(0.85))),
          ),
          // Transcript
          Align(
            alignment: const Alignment(0, 0.62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _bubble(
                    'Hey Alter, should I learn AI or Cybersecurity?', true, null),
                const SizedBox(height: 12),
                _bubble(
                    'Your Python edge favours AI — but I found a sharper third '
                    'path. Let me show the council\'s reasoning.',
                    false,
                    LinearGradient(colors: [
                      AppColors.lime.withValues(alpha: 0.16),
                      AppColors.purple.withValues(alpha: 0.14),
                    ])),
              ]),
            ),
          ),
          // Deep analysis CTA
          Align(
            alignment: const Alignment(0, 0.96),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeepAnalysisScreen())),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.white(0.06),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.white(0.16)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Deep analysis',
                        style: AppText.body(14, weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _rings() {
    return List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _ring,
        builder: (_, __) {
          final t = ((_ring.value + i / 3) % 1.0);
          return Container(
            width: 170 + t * 150,
            height: 170 + t * 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.lime.withValues(alpha: (1 - t) * 0.5),
                width: 2,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _orb() {
    return GestureDetector(
      onTap: _cycle,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (_, child) {
          final s = 1 + _breathe.value * 0.06;
          return Transform.scale(scale: s, child: child);
        },
        child: Container(
          width: 170,
          height: 170,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.25, -0.3),
              colors: [AppColors.lime, AppColors.purple, AppColors.purpleDeep],
              stops: [0.0, 0.55, 0.8],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.6),
                blurRadius: 70,
                spreadRadius: 4,
              ),
            ],
          ),
          child: _orbContent(),
        ),
      ),
    );
  }

  Widget _orbContent() {
    switch (mode) {
      case VoiceMode.speaking:
        return SizedBox(
          height: 60,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(14, (i) {
              return AnimatedBuilder(
                animation: _wave,
                builder: (_, __) {
                  final phase = (i % 4) / 4;
                  final v = (0.3 +
                      0.7 *
                          (0.5 +
                              0.5 *
                                  (1 - 2 * ((_wave.value + phase) % 1.0 - 0.5).abs())));
                  return Container(
                    width: 5,
                    height: 38 * v,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              );
            }),
          ),
        );
      case VoiceMode.listening:
        return const Icon(Icons.mic, size: 40, color: AppColors.bg);
      case VoiceMode.idle:
        return const StarMark(size: 42, color: AppColors.bg);
    }
  }

  Widget _bubble(String text, bool me, Gradient? grad) {
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * (me ? 0.78 : 0.82)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: me ? AppColors.white(0.1) : null,
          gradient: grad,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(me ? 20 : 6),
            bottomRight: Radius.circular(me ? 6 : 20),
          ),
          border: Border.all(
              color: me
                  ? AppColors.white(0.14)
                  : AppColors.lime.withValues(alpha: 0.25)),
        ),
        child: Text(text, style: AppText.body(14, height: 1.5)),
      ),
    );
  }
}

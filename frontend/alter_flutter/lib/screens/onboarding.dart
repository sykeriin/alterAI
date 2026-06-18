import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../main.dart';

// ============================================================
// Login
// ============================================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2A1F4A), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.0, -1.0),
        orbs: [
          PositionedOrb(
            top: -40,
            left: 0,
            right: 0,
            orb: Orb(size: 280, blur: 20, colors: [
              AppColors.purple.withValues(alpha: 0.6),
            ]),
          ),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.white(0.14)),
                  ),
                  child: const StarMark(size: 26),
                ),
                const SizedBox(height: 26),
                Text('Welcome to your\nfuture.',
                    style: AppText.display(34, weight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text('Sign in and Alter starts learning your context.',
                    style: AppText.body(15, color: AppColors.white(0.55))),
                const SizedBox(height: 34),
                _field(Icons.mail_outline, 'aarav@email.com'),
                const SizedBox(height: 12),
                _field(Icons.lock_outline, '••••••••', obscure: true),
                const SizedBox(height: 18),
                LimeButton(
                  label: 'Continue',
                  trailing: null,
                  onTap: () => Navigator.pushNamed(context, Routes.languages),
                ),
                const SizedBox(height: 26),
                Row(children: [
                  Expanded(child: Container(height: 1, color: AppColors.white(0.12))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: AppText.body(12, color: AppColors.white(0.3))),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.white(0.12))),
                ]),
                const SizedBox(height: 26),
                Row(children: [
                  Expanded(
                      child: _social(
                          'Google', () => Navigator.pushNamed(context, Routes.languages))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _social(
                          'Apple', () => Navigator.pushNamed(context, Routes.languages))),
                ]),
                const SizedBox(height: 30),
                Center(
                  child: Text('Privacy-first · on-device by default',
                      style: AppText.body(12, color: AppColors.white(0.4))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(IconData icon, String hint, {bool obscure = false}) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.white(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white(0.12)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.white(0.4)),
        const SizedBox(width: 12),
        Text(hint,
            style: AppText.body(15,
                color: AppColors.white(0.45),
                letterSpacing: obscure ? 3 : 0)),
      ]),
    );
  }

  Widget _social(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white(0.12)),
        ),
        child: Text(label, style: AppText.body(14, weight: FontWeight.w600)),
      ),
    );
  }
}

// ============================================================
// Languages
// ============================================================
class LanguagesScreen extends StatefulWidget {
  const LanguagesScreen({super.key});
  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  static const all = [
    'English', 'Hindi', 'Kannada', 'Tamil',
    'Telugu', 'Malayalam', 'Marathi', 'Bengali',
  ];
  final selected = <String>{'English', 'Hindi'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2C2150), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.6, -1.0),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STEP 1 OF 2', style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 14),
                Text('What languages\ndo you speak?',
                    style: AppText.display(32, weight: FontWeight.w500, height: 1.1)),
                const SizedBox(height: 10),
                Text(
                  'Alter thinks natively in each — switch mid-sentence and it '
                  'keeps up.',
                  style: AppText.body(14.5, color: AppColors.white(0.55)),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 11,
                  runSpacing: 11,
                  children: all
                      .map((l) => PillChip(
                            label: l,
                            selected: selected.contains(l),
                            onTap: () => setState(() {
                              selected.contains(l)
                                  ? selected.remove(l)
                                  : selected.add(l);
                            }),
                          ))
                      .toList(),
                ),
                const Spacer(),
                LimeButton(
                  label: 'Continue',
                  onTap: () => Navigator.pushNamed(context, Routes.about),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// About You
// ============================================================
class AboutYouScreen extends StatefulWidget {
  const AboutYouScreen({super.key});
  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends State<AboutYouScreen> {
  static const roles = [
    'Student', 'Working', 'Job seeker',
    'Founder', 'Career switcher', 'Researcher',
  ];
  String role = 'Student';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF3A2566), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(-0.6, -1.0),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STEP 2 OF 2', style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 14),
                Text('Tell us more\nabout yourself.',
                    style: AppText.display(32, weight: FontWeight.w500, height: 1.1)),
                const SizedBox(height: 24),
                Text('WHERE ARE YOU RIGHT NOW?',
                    style: AppText.kicker(AppColors.white(0.45), size: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: roles
                      .map((r) => PillChip(
                            label: r,
                            selected: role == r,
                            onTap: () => setState(() => role = r),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 26),
                Text('YOUR CURRENT STATE',
                    style: AppText.kicker(AppColors.white(0.45), size: 12)),
                const SizedBox(height: 12),
                _stateRow('B.Tech · CSE, Year 3', 'Python · React · some ML'),
                const SizedBox(height: 10),
                _stateRow('Tier-2 city · Open to remote', '~15 focus hours / week'),
                const SizedBox(height: 26),
                Text('FUTURE PLANS',
                    style: AppText.kicker(AppColors.white(0.45), size: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.lime.withValues(alpha: 0.14),
                        AppColors.purple.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lime.withValues(alpha: 0.25)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: AppText.body(15, color: AppColors.white(0.85), height: 1.5),
                      children: const [
                        TextSpan(text: '"I want to become an '),
                        TextSpan(
                            text: 'AI Engineer',
                            style: TextStyle(
                                color: AppColors.lime, fontWeight: FontWeight.w700)),
                        TextSpan(
                            text:
                                ' and ship something of my own within 3 years."'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                LimeButton(
                  label: 'Enter Alter',
                  height: 62,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context, Routes.home, (r) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateRow(String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.body(12.5, color: AppColors.white(0.5))),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.lime),
        ],
      ),
    );
  }
}

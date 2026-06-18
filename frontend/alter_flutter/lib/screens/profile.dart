import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'main_shell.dart';
import 'deep.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    return GradientScaffold(
      bgColors: const [Color(0xFF2E2052), Color(0xFF150F24), AppColors.bg],
      bgCenter: const Alignment(0.0, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'PROFILE',
              showAvatar: false,
              onGear: shell.openSettings,
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.purpleLight, AppColors.pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleLight.withValues(alpha: 0.5),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Text('A', style: AppText.display(38, weight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                Text('Aarav Sharma', style: AppText.display(24, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('B.Tech CSE · Aspiring AI Engineer',
                    style: AppText.body(13.5, color: AppColors.white(0.5))),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              _stat('78', 'Reputation', AppColors.lime),
              const SizedBox(width: 10),
              _stat('12', 'Pursued', AppColors.cyan),
              const SizedBox(width: 10),
              _stat('31', 'Day streak', AppColors.orange),
            ]),
            const SizedBox(height: 18),
            // Social graph entry
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SocialGraphScreen())),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.pink.withValues(alpha: 0.16),
                    AppColors.purpleLight.withValues(alpha: 0.06),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const RadialGradient(
                        center: Alignment(-0.2, -0.2),
                        colors: [AppColors.pink, AppColors.purpleLight],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Social Graph',
                            style: AppText.body(16, weight: FontWeight.w600)),
                        Text('Your network, mapped by Alter',
                            style: AppText.body(12.5, color: AppColors.white(0.6))),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.white(0.5), size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 11),
            // NFC
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.cyan.withValues(alpha: 0.14),
                  AppColors.cyan.withValues(alpha: 0.04),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.contactless_outlined,
                      color: AppColors.cyan, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tap to connect · NFC',
                          style: AppText.body(16, weight: FontWeight.w600)),
                      Text('Share a context-aware profile',
                          style: AppText.body(12.5, color: AppColors.white(0.6))),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 26),
            Text('CONNECTED PLATFORMS',
                style: AppText.kicker(AppColors.white(0.45), size: 12)),
            const SizedBox(height: 12),
            Row(children: [
              _platform('N', 'Notion', circle: false),
              const SizedBox(width: 10),
              _platform('GH', 'GitHub', circle: true),
            ]),
            const SizedBox(height: 16),
            OutlineButton2(label: 'Account & settings', onTap: shell.openSettings),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color c) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        radius: 16,
        child: Column(children: [
          Text(value, style: AppText.display(22, weight: FontWeight.w600, color: c)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(11, color: AppColors.white(0.5))),
        ]),
      ),
    );
  }

  Widget _platform(String mark, String name, {required bool circle}) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 14,
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle ? null : BorderRadius.circular(7),
            ),
            child: Text(mark,
                style: AppText.body(circle ? 12 : 14,
                    weight: FontWeight.w800, color: Colors.black)),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.body(13, weight: FontWeight.w600)),
              Text('Synced', style: AppText.body(10, color: AppColors.lime)),
            ],
          ),
        ]),
      ),
    );
  }
}

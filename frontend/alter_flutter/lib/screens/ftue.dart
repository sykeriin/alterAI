import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../main.dart';

// ============================================================
// FTUE 1 — What is Alter
// ============================================================
class FtueWhatScreen extends StatelessWidget {
  const FtueWhatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF3A2566), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.6, -1.0),
        orbs: [
          PositionedOrb(
            top: 120,
            left: -60,
            orb: const Orb(size: 340, colors: [
              AppColors.purpleLight,
              AppColors.purpleDeep,
            ], blur: 8),
          ),
          PositionedOrb(
            top: 240,
            right: -40,
            orb: const Orb(size: 200, colors: [
              AppColors.orange,
              Color(0xFFFF4D2D),
            ], blur: 10),
          ),
        ],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const StarMark(size: 22),
                  const SizedBox(width: 8),
                  Text('ALTER',
                      style: AppText.display(14,
                          weight: FontWeight.w600, letterSpacing: 3)),
                ]),
                const Spacer(),
                Text('WHAT IS ALTER', style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 18),
                RichText(
                  text: TextSpan(
                    style: AppText.display(42, height: 1.06),
                    children: const [
                      TextSpan(text: 'Not an assistant.\nA '),
                      TextSpan(
                          text: 'future',
                          style: TextStyle(color: AppColors.lime)),
                      TextSpan(text: ' operating system.'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  "Today's AI waits for you to ask. Alter is proactive — it "
                  "understands your context, simulates your possible futures, "
                  "and surfaces intelligence before you even think to ask.",
                  style: AppText.body(16,
                      color: AppColors.white(0.62), height: 1.55),
                ),
                const Spacer(),
                Row(children: [
                  _dot(22, AppColors.lime),
                  const SizedBox(width: 8),
                  _dot(5, AppColors.white(0.25)),
                  const SizedBox(width: 8),
                  _dot(5, AppColors.white(0.25)),
                ]),
                const SizedBox(height: 20),
                LimeButton(
                  label: 'Discover Alter',
                  height: 62,
                  onTap: () => Navigator.pushNamed(context, Routes.features),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(double w, Color c) => Container(
        width: w,
        height: 5,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      );
}

// ============================================================
// FTUE 2 — What Alter does (5 feature pages, swipeable)
// ============================================================
class FeatureData {
  final String kicker, title, body;
  final List<String> chips;
  final List<Color> bg;
  final List<Color> orb;
  final Color glyph;
  const FeatureData(this.kicker, this.title, this.body, this.chips, this.bg,
      this.orb, this.glyph);
}

const features = <FeatureData>[
  FeatureData(
    'CLONE COUNCIL',
    'Five minds debate your decision.',
    'Instead of one answer, consult a council of five AI personas — each a '
        'different lens — that reason against each other before giving you a '
        'synthesised recommendation.',
    ['Current You', 'Future You', 'Founder You', 'Realist You', 'Explorer You'],
    [Color(0xFF4A2D8F), Color(0xFF1A1230), AppColors.bg],
    [AppColors.purpleLight, AppColors.purpleDeep],
    AppColors.lime,
  ),
  FeatureData(
    'FUTURE SIMULATOR',
    'Run your life forward before you decide.',
    'Pose any major decision and Alter builds multiple parallel futures — '
        'skill roadmap, salary, demand, risk and a 0–100 Fit Score — computed '
        'against your real profile.',
    ['Fit Score', 'Salary range', 'Risk analysis', '30-day plan'],
    [Color(0xFF1D3A8F), Color(0xFF131A33), AppColors.bg],
    [AppColors.cyan, AppColors.cyanDeep],
    AppColors.cyan,
  ),
  FeatureData(
    'GHOST VISION + VOICE',
    'Point, or just say "Hey Alter."',
    'Scan a poster, CV, logo or research paper for instant intelligence — or '
        'speak naturally to an advisor who already knows your full context. '
        'No prompts, no forms.',
    ['Camera scan', 'Wake word', 'Multi-turn memory', '8 languages'],
    [Color(0xFFB3431A), Color(0xFF3A1A14), AppColors.bg],
    [AppColors.orange, Color(0xFFFF4D2D)],
    Color(0xFFFFD23C),
  ),
  FeatureData(
    'OPPORTUNITY RADAR',
    'Opportunity finds you.',
    'Alter continuously scans hackathons, internships, grants, research and '
        'open-source — and delivers the ones where you have a real edge, each '
        'with a Match Score and a reason.',
    ['Hackathons', 'Internships', 'Scholarships', 'GSoC'],
    [Color(0xFF0F6B4A), Color(0xFF0F2620), AppColors.bg],
    [AppColors.green, AppColors.greenDeep],
    AppColors.green,
  ),
  FeatureData(
    'LIFE FEED',
    'One surface. Your whole day, prioritised.',
    'Ten apps become one AI-curated briefing — the single most important '
        'thing to do now, your top opportunities, meeting briefs and goal '
        'progress, refreshed all day.',
    ['Tasks', 'Briefs', 'Deadlines', 'Goals'],
    [Color(0xFF8F2D6B), Color(0xFF2E1230), AppColors.bg],
    [AppColors.pink, AppColors.purpleLight],
    AppColors.pink,
  ),
];

class FeaturePagesScreen extends StatefulWidget {
  const FeaturePagesScreen({super.key});
  @override
  State<FeaturePagesScreen> createState() => _FeaturePagesScreenState();
}

class _FeaturePagesScreenState extends State<FeaturePagesScreen> {
  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index >= features.length - 1) {
      Navigator.pushReplacementNamed(context, Routes.getStarted);
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = features[_index];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.4, -1.0),
            radius: 1.3,
            colors: f.bg,
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Center(
                child: Orb(size: 300, colors: f.orb, blur: 30)),
          ),
          PageView.builder(
            controller: _controller,
            itemCount: features.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _FeaturePage(features[i], i + 1),
          ),
          // Footer controls
          Positioned(
            left: 30,
            right: 30,
            bottom: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(features.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 7),
                      width: active ? 20 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: active ? AppColors.lime : AppColors.white(0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.lime.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward,
                        color: AppColors.bg, size: 26),
                  ),
                ),
              ],
            ),
          ),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 12, 30, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('WHAT ALTER DOES · ${_index + 1}/5',
                      style: AppText.kicker(AppColors.white(0.55))),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(
                        context, Routes.getStarted),
                    child: Text('Skip',
                        style: AppText.body(13,
                            weight: FontWeight.w600,
                            color: AppColors.white(0.5))),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final FeatureData f;
  final int idx;
  const _FeaturePage(this.f, this.idx);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 60, 30, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.white(0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.white(0.18)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                StarMark(size: 16, color: f.glyph),
                const SizedBox(width: 8),
                Text(f.kicker,
                    style: AppText.body(12,
                        weight: FontWeight.w700, letterSpacing: 0.8)),
              ]),
            ),
            const SizedBox(height: 18),
            Text(f.title, style: AppText.display(40, weight: FontWeight.w500, height: 1.04)),
            const SizedBox(height: 18),
            Text(f.body,
                style: AppText.body(15.5,
                    color: AppColors.white(0.72), height: 1.55)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: f.chips.map((c) => TagChip(c)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FTUE 3 — Get Started / Bloom
// ============================================================
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [AppColors.lime, Color(0xFF6F8F2E), Color(0xFF15101F), AppColors.bg],
        bgStops: const [],
        bgCenter: const Alignment(0.0, 1.1),
        orbs: [
          PositionedOrb(
            bottom: 120,
            left: 0,
            right: 0,
            orb: Orb(size: 360, blur: 20, colors: [
              AppColors.lime.withValues(alpha: 0.55),
              AppColors.purple.withValues(alpha: 0.3),
            ]),
          ),
        ],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const StarMark(size: 22),
                  const SizedBox(width: 8),
                  Text('ALTER',
                      style: AppText.display(14,
                          weight: FontWeight.w600, letterSpacing: 3)),
                ]),
                const SizedBox(height: 54),
                RichText(
                  text: TextSpan(
                    style: AppText.display(46, height: 1.04),
                    children: const [
                      TextSpan(text: 'See how Alter helps your future '),
                      TextSpan(
                          text: 'bloom',
                          style: TextStyle(color: AppColors.lime)),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Five AI personas, a future simulator, and a radar that hunts '
                  'opportunity for you — all from a single "Hey Alter."',
                  style: AppText.body(16,
                      color: AppColors.white(0.66), height: 1.55),
                ),
                const Spacer(),
                LimeButton(
                  label: 'Get started',
                  height: 64,
                  onTap: () => Navigator.pushNamed(context, Routes.login),
                ),
                const SizedBox(height: 12),
                OutlineButton2(
                  label: 'I already have an account',
                  onTap: () => Navigator.pushNamed(context, Routes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

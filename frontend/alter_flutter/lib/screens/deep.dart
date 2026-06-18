import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

// ============================================================
// Shared deep-screen scaffold (back · title · gear)
// ============================================================
class _DeepScaffold extends StatelessWidget {
  final String title;
  final List<Color> bg;
  final Alignment bgCenter;
  final Widget child;
  const _DeepScaffold({
    required this.title,
    required this.bg,
    required this.child,
    this.bgCenter = const Alignment(0.0, -1.0),
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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackPill(onTap: () => Navigator.maybePop(context)),
                    Text(title,
                        style: AppText.display(13,
                            weight: FontWeight.w600, letterSpacing: 2.0)),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CLONE COUNCIL — 5-persona carousel
// ============================================================
class Persona {
  final String name, tag, q, body;
  final Color c1, c2;
  const Persona(this.name, this.tag, this.q, this.body, this.c1, this.c2);
}

const personas = <Persona>[
  Persona('Current You', 'Present circumstances',
      'Given where you are right now — is this actually achievable?',
      'Anchors every recommendation in your current skills, time and constraints. Finds the minimum viable path from today to the outcome.',
      AppColors.lime, Color(0xFF7F9E2E)),
  Persona('Future You', '5–10 year horizon',
      'Will your 35-year-old self thank you for this?',
      'Projects long-term compounding effects. Which skills grow exponentially? Which doors close? Weighs upside against long-term regret.',
      AppColors.purpleLight, AppColors.purpleDeep),
  Persona('Founder You', 'Entrepreneurial lens',
      'Can this decision generate asymmetric upside?',
      'Finds the startup hidden in any path — side-project viability, commercialisation, and which option gives you the most optionality.',
      AppColors.orange, AppColors.orangeDeep),
  Persona('Realist You', 'Systematic scepticism',
      'What do the real odds actually look like?',
      'Counters optimism with data — market demand, job availability, income trajectories and execution feasibility. The cold read.',
      AppColors.cyan, AppColors.cyanDeep),
  Persona('Explorer You', 'Non-obvious paths',
      'What are you not even seeing yet?',
      'Surfaces adjacent domains and emerging fields with first-mover advantage — the third option you never considered.',
      AppColors.pink, AppColors.pinkDeep),
];

class CloneCouncilScreen extends StatefulWidget {
  const CloneCouncilScreen({super.key});
  @override
  State<CloneCouncilScreen> createState() => _CloneCouncilScreenState();
}

class _CloneCouncilScreenState extends State<CloneCouncilScreen> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _to(int i) {
    final t = i.clamp(0, personas.length - 1);
    _controller.animateToPage(t,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return _DeepScaffold(
      title: 'CLONE COUNCIL',
      bg: const [Color(0xFF2E1D5C), Color(0xFF160F2C), AppColors.bg],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 16,
            child: Row(children: [
              const StarMark(size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppText.body(14, color: AppColors.white(0.85)),
                    children: const [
                      TextSpan(text: '"Should I learn '),
                      TextSpan(text: 'AI', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                      TextSpan(text: ' or '),
                      TextSpan(text: 'Cybersecurity', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                      TextSpan(text: '?"'),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Five minds are deliberating · swipe to hear each',
              style: AppText.body(12.5, color: AppColors.white(0.5))),
          const SizedBox(height: 12),
          SizedBox(
            height: 350,
            child: PageView.builder(
              controller: _controller,
              itemCount: personas.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _card(personas[i], i + 1),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(Icons.arrow_back, () => _to(_index - 1)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(personas.length, (i) {
                  final active = i == _index;
                  return GestureDetector(
                    onTap: () => _to(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: active ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? personas[i].c1 : AppColors.white(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              _circleBtn(Icons.arrow_forward, () => _to(_index + 1)),
            ],
          ),
          const SizedBox(height: 24),
          // Synthesis
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.lime.withValues(alpha: 0.16),
                AppColors.purple.withValues(alpha: 0.10),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYNTHESISED RECOMMENDATION',
                    style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: AppText.display(24, weight: FontWeight.w500),
                    children: const [
                      TextSpan(text: 'Pursue '),
                      TextSpan(text: 'AI Security', style: TextStyle(color: AppColors.lime)),
                      TextSpan(text: ' — the third path.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Explorer You found the convergence of both domains: minimal '
                  'competition, very high enterprise demand, and it builds on '
                  'your Python edge.',
                  style: AppText.body(13.5, color: AppColors.white(0.78), height: 1.55),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const FutureSimulatorScreen())),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text('Simulate this path →',
                        style: AppText.body(14,
                            weight: FontWeight.w700, color: AppColors.bg)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white(0.06),
          border: Border.all(color: AppColors.white(0.16)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _card(Persona p, int n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.c2, AppColors.bgRaised.withValues(alpha: 0.4)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.c1),
                child: Text('$n',
                    style: AppText.display(22, weight: FontWeight.w700, color: AppColors.bg)),
              ),
              Text(p.tag.toUpperCase(),
                  style: AppText.kicker(AppColors.white(0.7), size: 10)),
            ],
          ),
          const SizedBox(height: 18),
          Text(p.name, style: AppText.display(30, weight: FontWeight.w500)),
          const SizedBox(height: 14),
          Text('"${p.q}"',
              style: AppText.display(18,
                  weight: FontWeight.w400,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0)),
          const SizedBox(height: 14),
          Text(p.body,
              style: AppText.body(14, color: AppColors.white(0.78), height: 1.55)),
        ],
      ),
    );
  }
}

// ============================================================
// FUTURE SIMULATOR
// ============================================================
class SimFuture {
  final String name, role, salary, senior, demand, startup;
  final int fit;
  final Color c;
  final List<String> skills;
  const SimFuture(this.name, this.fit, this.c, this.role, this.salary,
      this.senior, this.demand, this.startup, this.skills);
}

const simFutures = <SimFuture>[
  SimFuture('AI Engineer', 92, AppColors.lime, 'ML Engineer / Data Scientist',
      '₹12–25 LPA', '3–5 yrs', 'Very high · +35% YoY', 'High',
      ['ML', 'Deep learning', 'MLOps', 'Cloud']),
  SimFuture('Cybersecurity', 74, AppColors.cyan, 'SOC Analyst / Pen Tester',
      '₹8–20 LPA', '4–6 yrs', 'High · govt & enterprise', 'Moderate',
      ['Pentesting', 'SIEM', 'Network', 'CISSP']),
];

class FutureSimulatorScreen extends StatefulWidget {
  const FutureSimulatorScreen({super.key});
  @override
  State<FutureSimulatorScreen> createState() => _FutureSimulatorScreenState();
}

class _FutureSimulatorScreenState extends State<FutureSimulatorScreen> {
  int choice = 0;

  @override
  Widget build(BuildContext context) {
    return _DeepScaffold(
      title: 'FUTURE SIMULATOR',
      bg: const [Color(0xFF14306E), Color(0xFF101A33), AppColors.bg],
      bgCenter: const Alignment(-0.4, -1.0),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          RichText(
            text: TextSpan(
              style: AppText.display(27, height: 1.1),
              children: const [
                TextSpan(text: 'Two parallel futures,\ncomputed for '),
                TextSpan(text: 'you', style: TextStyle(color: AppColors.cyan)),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Tap a path to expand its 5-year projection.',
              style: AppText.body(12.5, color: AppColors.white(0.5))),
          const SizedBox(height: 18),
          for (var i = 0; i < simFutures.length; i++) ...[
            _futureCard(simFutures[i], i == choice, () => setState(() => choice = i)),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
          // 30-day plan
          GlassCard(
            padding: const EdgeInsets.all(18),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ALTER'S 30-DAY PLAN", style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 12),
                _planRow(AppColors.lime, 'Week 1–2:',
                    ' Fine-tune an open LLM, publish the repo.'),
                _planRow(AppColors.cyan, 'Week 3:',
                    ' Ship to the GenAI hackathon (94% match).'),
                _planRow(AppColors.orange, 'Week 4:',
                    ' Apply to Sarvam AI with the new portfolio.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planRow(Color c, String bold, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.body(13.5, color: AppColors.white(0.82), height: 1.45),
                children: [
                  TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _futureCard(SimFuture f, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(colors: [
                  AppColors.white(0.08),
                  AppColors.white(0.02),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: sel ? null : AppColors.white(0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? f.c : AppColors.white(0.10)),
          boxShadow: sel
              ? [BoxShadow(color: f.c.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: AppText.display(21, weight: FontWeight.w600)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${f.fit}',
                        style: AppText.display(26, weight: FontWeight.w600, color: f.c)),
                    Text('FIT SCORE', style: AppText.kicker(AppColors.white(0.5), size: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(f.role, style: AppText.body(12.5, color: AppColors.white(0.6))),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: f.fit / 100,
                minHeight: 8,
                backgroundColor: AppColors.white(0.1),
                valueColor: AlwaysStoppedAnimation(f.c),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _metric('SALARY (5YR)', f.salary),
              _metric('SENIOR IN', f.senior),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _metric('DEMAND', f.demand),
              _metric('STARTUP UPSIDE', f.startup),
            ]),
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: f.skills
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.white(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(s,
                            style: AppText.body(11.5, weight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.kicker(AppColors.white(0.45), size: 10)),
          const SizedBox(height: 2),
          Text(value, style: AppText.body(14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// OPPORTUNITY RADAR
// ============================================================
class RadarOpp {
  final int m, days;
  final Color c;
  final String tag, title, org, why;
  const RadarOpp(this.m, this.c, this.tag, this.title, this.org, this.why, this.days);
}

const radarOpps = <RadarOpp>[
  RadarOpp(94, AppColors.lime, 'Hackathon', 'GenAI Hack 2026', 'Bengaluru · ₹5L pool',
      'Strong team-size win rate + 3 target sponsors', 6),
  RadarOpp(88, AppColors.cyan, 'Internship', 'ML Engineer Intern', 'Sarvam AI · Remote',
      'React + Python match your profile', 11),
  RadarOpp(83, AppColors.orange, 'Research', 'Summer ML @ IIT-B', 'CSIR-aligned lab',
      'Fits your academic focus', 21),
  RadarOpp(79, AppColors.green, 'Open-source', 'GSoC · vLLM tooling', 'Good first issue',
      'In a framework you are learning', 30),
  RadarOpp(72, AppColors.pink, 'Grant', 'iCreate Seed Grant', 'Project stage eligible',
      'Your side-project qualifies', 40),
];

class OpportunityRadarScreen extends StatefulWidget {
  const OpportunityRadarScreen({super.key});
  @override
  State<OpportunityRadarScreen> createState() => _OpportunityRadarScreenState();
}

class _OpportunityRadarScreenState extends State<OpportunityRadarScreen>
    with SingleTickerProviderStateMixin {
  static const filters = ['All', 'Hackathons', 'Internships', 'Grants', 'Research', 'Open-source'];
  int filter = 0;
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DeepScaffold(
      title: 'OPPORTUNITY RADAR',
      bg: const [Color(0xFF0D5C40), Color(0xFF0D2620), AppColors.bg],
      bgCenter: const Alignment(0.4, -1.0),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (_, __) =>
                    CustomPaint(painter: _RadarPainter(_sweep.value)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: RichText(
              text: TextSpan(
                style: AppText.body(13, color: AppColors.white(0.6)),
                children: const [
                  TextSpan(text: '5 matches',
                      style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' found while you slept'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = i == filter;
                return GestureDetector(
                  onTap: () => setState(() => filter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? AppColors.green.withValues(alpha: 0.16) : AppColors.white(0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: on ? AppColors.green : AppColors.white(0.14)),
                    ),
                    child: Text(filters[i],
                        style: AppText.body(12.5,
                            weight: FontWeight.w600,
                            color: on ? AppColors.green : AppColors.white(0.7))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          ...radarOpps.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _oppCard(o),
              )),
        ],
      ),
    );
  }

  Widget _oppCard(RadarOpp o) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.tag.toUpperCase(), style: AppText.kicker(o.c, size: 10)),
              Row(children: [
                Text('${o.m}',
                    style: AppText.display(15, weight: FontWeight.w700, color: o.c)),
                const SizedBox(width: 6),
                Text('MATCH', style: AppText.kicker(AppColors.white(0.45), size: 10)),
              ]),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.title, style: AppText.body(16, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(o.org, style: AppText.body(12.5, color: AppColors.white(0.55))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.white(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichText(
              text: TextSpan(
                style: AppText.body(12.5, color: AppColors.white(0.7)),
                children: [
                  TextSpan(text: 'Why you: ', style: TextStyle(color: o.c)),
                  TextSpan(text: o.why),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⏳ ${o.days} days left',
                  style: AppText.body(12, color: AppColors.white(0.5))),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o.c,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('Pursue',
                    style: AppText.body(13, weight: FontWeight.w700, color: AppColors.bg)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (final f in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(
          c,
          r * f,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = AppColors.green.withValues(alpha: 0.22 * f + 0.05));
    }
    // sweep
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2.2,
        colors: [Colors.transparent, AppColors.green.withValues(alpha: 0.35), Colors.transparent],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, sweep);
    // center + blips
    canvas.drawCircle(c, 5, Paint()..color = AppColors.green);
    void blip(double dx, double dy, Color col, double rad) {
      canvas.drawCircle(c + Offset(dx, dy), rad, Paint()..color = col);
    }
    blip(r * 0.24, -r * 0.48, AppColors.lime, 4);
    blip(-r * 0.32, r * 0.28, AppColors.cyan, 3.5);
    blip(r * 0.56, -r * 0.20, AppColors.orange, 3);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}

// ============================================================
// SOCIAL GRAPH
// ============================================================
class _Node {
  final double x, y, r;
  final String label;
  final Color c;
  final bool big;
  const _Node(this.x, this.y, this.r, this.label, this.c, {this.big = false});
}

const _nodes = <_Node>[
  _Node(0.5, 0.42, 30, 'You', AppColors.lime, big: true),
  _Node(0.22, 0.20, 18, 'Prof. Nair', AppColors.purpleLight),
  _Node(0.80, 0.22, 16, 'Sarvam', AppColors.cyan),
  _Node(0.18, 0.74, 15, 'Hack team', AppColors.orange),
  _Node(0.82, 0.72, 17, 'GDG BLR', AppColors.green),
  _Node(0.5, 0.88, 14, 'Mentor', AppColors.pink),
];

class SocialGraphScreen extends StatelessWidget {
  const SocialGraphScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DeepScaffold(
      title: 'SOCIAL GRAPH',
      bg: const [Color(0xFF3A1D52), Color(0xFF160F28), AppColors.bg],
      bgCenter: const Alignment(0.0, -0.4),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          RichText(
            text: TextSpan(
              style: AppText.display(26, height: 1.1),
              children: const [
                TextSpan(text: 'Your network,\nmapped by '),
                TextSpan(text: 'Alter', style: TextStyle(color: AppColors.pink)),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: AppColors.white(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.white(0.1)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth, h = c.maxHeight;
                final center = Offset(_nodes[0].x * w, _nodes[0].y * h);
                return Stack(children: [
                  CustomPaint(
                    size: Size(w, h),
                    painter: _EdgesPainter(center, _nodes, w, h),
                  ),
                  ..._nodes.map((n) => Positioned(
                        left: n.x * w - n.r,
                        top: n.y * h - n.r - 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: n.r * 2,
                              height: n.r * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.25, -0.3),
                                  colors: [n.c, n.c.withValues(alpha: 0.6)],
                                ),
                                border: Border.all(
                                    color: n.big
                                        ? AppColors.white(0.5)
                                        : AppColors.white(0.2),
                                    width: n.big ? 3 : 1),
                                boxShadow: [
                                  BoxShadow(
                                      color: n.c.withValues(alpha: 0.6),
                                      blurRadius: n.big ? 30 : 16),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(n.label,
                                style: AppText.body(11,
                                    weight: FontWeight.w600,
                                    color: AppColors.white(0.85))),
                          ],
                        ),
                      )),
                ]);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('ALTER SUGGESTS REACHING OUT',
              style: AppText.kicker(AppColors.white(0.45), size: 12)),
          const SizedBox(height: 12),
          _suggest(AppColors.purpleLight, AppColors.purpleDeep, 'Prof. Nair',
              'Has a research-lab slot opening — reply today', 'Draft'),
          const SizedBox(height: 10),
          _suggest(AppColors.green, AppColors.greenDeep, 'GDG Bengaluru',
              'Hosting the hackathon you matched 94%', 'Intro'),
        ],
      ),
    );
  }

  Widget _suggest(Color c1, Color c2, String name, String sub, String action) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [c1, c2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.body(14.5, weight: FontWeight.w600)),
              Text(sub, style: AppText.body(12, color: AppColors.white(0.55))),
            ],
          ),
        ),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(action,
              style: AppText.body(12, weight: FontWeight.w700, color: AppColors.bg)),
        ),
      ]),
    );
  }
}

class _EdgesPainter extends CustomPainter {
  final Offset center;
  final List<_Node> nodes;
  final double w, h;
  _EdgesPainter(this.center, this.nodes, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.white(0.18)
      ..strokeWidth = 1;
    for (final n in nodes) {
      if (n.big) continue;
      canvas.drawLine(center, Offset(n.x * w, n.y * h), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// DEEP ANALYSIS
// ============================================================
class _Trace {
  final String k, v;
  final Color c;
  const _Trace(this.k, this.v, this.c);
}

const _trace = <_Trace>[
  _Trace('Context', 'Calendar shows an unusually clear week ahead', AppColors.cyan),
  _Trace('Career', 'Portfolio missing a recent LLM fine-tuning project', AppColors.lime),
  _Trace('Opportunity', 'A 48h hackathon matches the exact gap (72% fit)', AppColors.orange),
  _Trace('Research', '3 of your target companies are sponsoring it', AppColors.pink),
];

class DeepAnalysisScreen extends StatelessWidget {
  const DeepAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DeepScaffold(
      title: 'DEEP ANALYSIS',
      bg: const [Color(0xFF1A1430), Color(0xFF0D0A16), Color(0xFF060409)],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          Row(children: [
            const StarMark(size: 18),
            const SizedBox(width: 10),
            Text('Reasoning trace · how Alter concluded',
                style: AppText.body(13, color: AppColors.white(0.6))),
          ]),
          const SizedBox(height: 14),
          Text('"Do a 48-hour hackathon\nthis weekend."',
              style: AppText.display(25, weight: FontWeight.w400, height: 1.15)),
          const SizedBox(height: 24),
          Column(
            children: List.generate(_trace.length, (i) {
              final t = _trace[i];
              final last = i == _trace.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.c,
                          border: Border.all(color: const Color(0xFF0D0A16), width: 4),
                        ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: AppColors.white(0.12),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: last ? 0 : 18, top: 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.white(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.white(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.k.toUpperCase(), style: AppText.kicker(t.c)),
                              const SizedBox(height: 4),
                              Text(t.v,
                                  style: AppText.body(14,
                                      color: AppColors.white(0.85), height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.lime.withValues(alpha: 0.16),
                AppColors.purple.withValues(alpha: 0.10),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONCLUSION', style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: AppText.body(15, color: AppColors.white(0.88), height: 1.55),
                    children: const [
                      TextSpan(text: 'All four signals converge on one action with a '),
                      TextSpan(
                          text: '72% projected fit gain',
                          style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700)),
                      TextSpan(text: '. Confidence: high.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: AppColors.lime, borderRadius: BorderRadius.circular(14)),
                      child: Text('Add to plan',
                          style: AppText.body(14, weight: FontWeight.w700, color: AppColors.bg)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.white(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.white(0.16)),
                      ),
                      child: Text('Dismiss', style: AppText.body(14, weight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

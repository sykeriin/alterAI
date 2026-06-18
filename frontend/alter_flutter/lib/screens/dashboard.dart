import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'main_shell.dart';
import 'deep.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    return GradientScaffold(
      bgColors: const [Color(0xFF241A40), Color(0xFF120E1C), AppColors.bg],
      bgCenter: const Alignment(0.6, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'LIFE FEED',
              starTitle: true,
              onGear: shell.openSettings,
              onAvatar: () => shell.goTab(4),
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: AppText.display(30, height: 1.1, letterSpacing: -0.2),
                children: const [
                  TextSpan(text: 'Good morning,\n'),
                  TextSpan(
                      text: 'Aarav.',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Friday, 13 June · 4 things need you today',
                style: AppText.body(13.5, color: AppColors.white(0.45))),
            const SizedBox(height: 22),
            _focusHero(context, shell),
            const SizedBox(height: 30),
            _sectionHead('Opportunities for you', 'Radar →',
                () => _push(context, const OpportunityRadarScreen())),
            const SizedBox(height: 14),
            ..._opps.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _oppCard(context, o),
                )),
            const SizedBox(height: 18),
            Text("Today's tasks", style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            ..._tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _taskRow(t),
                )),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext c, Widget w) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  Widget _focusHero(BuildContext context, MainShellState shell) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgRaised,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.white(0.10)),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: Orb(size: 200, blur: 6, colors: const [
            AppColors.lime,
            AppColors.purple,
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FOCUS NOW', style: AppText.kicker(AppColors.lime)),
              const SizedBox(height: 12),
              SizedBox(
                width: 230,
                child: Text('Start the literature review for Project B',
                    style: AppText.display(23, weight: FontWeight.w500, height: 1.18)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 240,
                child: Text(
                  "Doing it this morning cuts next week's overload by ~40%.",
                  style: AppText.body(13.5, color: AppColors.white(0.6)),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => shell.goTab(2),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.pill,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ask Alter how',
                        style: AppText.body(14,
                            weight: FontWeight.w700, color: AppColors.pillInk)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.pillInk),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.body(16, weight: FontWeight.w700)),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: AppText.body(13,
                  weight: FontWeight.w600, color: AppColors.lime)),
        ),
      ],
    );
  }

  Widget _oppCard(BuildContext context, _Opp o) {
    return GlassCard(
      onTap: () => _push(context, const OpportunityRadarScreen()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: o.c),
          ),
          child: Text('${o.m}',
              style: AppText.display(15, weight: FontWeight.w700, color: o.c)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.tag, style: AppText.kicker(o.c, size: 10)),
              const SizedBox(height: 3),
              Text(o.title, style: AppText.body(14.5, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(o.meta, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _taskRow(_Task t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: t.hot
            ? LinearGradient(colors: [
                AppColors.lime.withValues(alpha: 0.12),
                AppColors.white(0.03),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: t.hot ? null : AppColors.white(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: t.hot ? AppColors.lime.withValues(alpha: 0.3) : AppColors.white(0.10)),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.done ? AppColors.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: t.done ? AppColors.lime : AppColors.white(0.3), width: 1.5),
          ),
          child: t.done
              ? const Icon(Icons.check, size: 14, color: AppColors.bg)
              : null,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title,
                  style: AppText.body(14.5,
                      weight: FontWeight.w600,
                      color: t.done ? AppColors.white(0.5) : AppColors.white(0.95))
                      .copyWith(
                          decoration: t.done ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text(t.meta, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ),
        Text(t.badge,
            style: AppText.body(11,
                weight: FontWeight.w700,
                color: t.badge == 'Now' ? AppColors.lime : AppColors.white(0.45))),
      ]),
    );
  }
}

class _Opp {
  final String tag, title, meta;
  final int m;
  final Color c;
  const _Opp(this.tag, this.m, this.c, this.title, this.meta);
}

const _opps = [
  _Opp('HACKATHON', 94, AppColors.lime, 'GenAI Hack · Bengaluru',
      'Deadline in 6 days · 3 sponsors on your list'),
  _Opp('INTERNSHIP', 88, AppColors.cyan, 'ML Engineer Intern · Sarvam AI',
      'Matches React + Python · Remote'),
  _Opp('GSoC', 81, AppColors.orange, 'Open-source · LLM tooling',
      'Good-first-issue in a repo you watch'),
];

class _Task {
  final bool done, hot;
  final String title, meta, badge;
  final Color badgeColor;
  const _Task(this.done, this.hot, this.title, this.meta, this.badge, this.badgeColor);
}

final _tasks = [
  _Task(true, false, 'Finish ML assignment A', 'Done · 2.5h', '2.5h', AppColors.white(0.4)),
  _Task(false, true, 'Start literature review · Project B',
      'Today · cuts next-week load 40%', 'Now', AppColors.lime),
  _Task(false, false, 'Reply to Prof. Nair', 'Pending · research lab slot', '2pm',
      AppColors.white(0.4)),
];

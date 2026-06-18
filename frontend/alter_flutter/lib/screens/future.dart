import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'main_shell.dart';
import 'deep.dart';

class FutureScreen extends StatelessWidget {
  const FutureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    return GradientScaffold(
      bgColors: const [Color(0xFF2A1D52), Color(0xFF130F22), AppColors.bg],
      bgCenter: const Alignment(-0.4, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'FUTURE',
              onGear: shell.openSettings,
              onAvatar: () => shell.goTab(4),
            ),
            const SizedBox(height: 22),
            RichText(
              text: TextSpan(
                style: AppText.display(30, height: 1.08, letterSpacing: -0.2),
                children: const [
                  TextSpan(text: "Build the future\nyou're "),
                  TextSpan(
                      text: 'simulating',
                      style: TextStyle(color: AppColors.lime)),
                  TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Forecast card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.orange.withValues(alpha: 0.16),
                  const Color(0xFFFF4D2D).withValues(alpha: 0.10),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppColors.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('FUTURE MODE · WORKLOAD FORECAST',
                        style: AppText.kicker(AppColors.orange, size: 11)),
                  ]),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: AppText.body(14.5, color: AppColors.white(0.85), height: 1.5),
                      children: const [
                        TextSpan(text: 'Overload likely '),
                        TextSpan(
                            text: 'Thu–Sun next week',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                        TextSpan(
                            text:
                                ' — 3 deliverables in a 48h window. Acting today reduces pressure ~40%.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Explore your futures', style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            _entry(context, 'Clone Council', '5 personas debate your decision',
                AppColors.purpleLight, AppColors.purpleDeep, const CloneCouncilScreen()),
            const SizedBox(height: 12),
            _entry(context, 'Future Simulator', 'Compare parallel paths · Fit Score',
                AppColors.cyan, AppColors.cyanDeep, const FutureSimulatorScreen()),
            const SizedBox(height: 12),
            _entry(context, 'Opportunity Radar', 'Matches found while you slept',
                AppColors.green, AppColors.greenDeep, const OpportunityRadarScreen()),
            const SizedBox(height: 30),
            Text('Recommended to build your future',
                style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Each step raises your AI Engineer Fit Score.',
                style: AppText.body(12.5, color: AppColors.white(0.5))),
            const SizedBox(height: 14),
            ..._recos.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _recoRow(r),
                )),
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, String title, String sub, Color c1,
      Color c2, Widget dest) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => dest)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c1.withValues(alpha: 0.18),
            c1.withValues(alpha: 0.04),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c1.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.2),
                colors: [c1, c2],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(17, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.body(12.5, color: AppColors.white(0.6))),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: AppColors.white(0.5), size: 20),
        ]),
      ),
    );
  }

  Widget _recoRow(_Reco r) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: r.c, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title, style: AppText.body(14.5, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(r.meta, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ),
        Text(r.fit,
            style: AppText.body(12, weight: FontWeight.w700, color: r.c)),
      ]),
    );
  }
}

class _Reco {
  final String title, meta, fit;
  final Color c;
  const _Reco(this.title, this.meta, this.fit, this.c);
}

const _recos = [
  _Reco('Ship an LLM fine-tuning project', 'Fills your portfolio gap', '+8 fit',
      AppColors.lime),
  _Reco('Earn the MLOps micro-cert', '14 days · high ROI', '+5 fit', AppColors.cyan),
  _Reco('Contribute to a vision repo', 'Builds reputation', '+4 fit', AppColors.orange),
];

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'main_shell.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    return GradientScaffold(
      bgColors: const [Color(0xFF2A1F55), Color(0xFF1A1338), Color(0xFF0D0A16)],
      bgCenter: const Alignment(0.0, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'STATS',
              onGear: shell.openSettings,
              onAvatar: () => shell.goTab(4),
            ),
            const SizedBox(height: 18),
            Text('Reputation', style: AppText.body(13, color: AppColors.white(0.55))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('78', style: AppText.display(64, weight: FontWeight.w500, height: 0.9)),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('▲ +6',
                          style: AppText.body(13,
                              weight: FontWeight.w700, color: AppColors.lime)),
                      Text('this month',
                          style: AppText.body(12, color: AppColors.white(0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _statRow(Icons.arrow_upward, AppColors.lime, 'Top domain',
                'AI Engineering', '92 Fit Score'),
            _statRow(Icons.arrow_downward, AppColors.orange, 'Focus area',
                'System Design', '54 Fit Score'),
            const SizedBox(height: 26),
            Row(children: [
              const StarMark(size: 14),
              const SizedBox(width: 8),
              Text('Reputation trend', style: AppText.body(13, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),
            _chart(),
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, Color c, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.white(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(width: 10),
            Text(label, style: AppText.body(13, color: AppColors.white(0.6))),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppText.display(24, weight: FontWeight.w500)),
              Text(sub, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chart() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(painter: _TrendPainter()),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.white(0.18)),
              ),
              child: Text('Fit 92 · Aug',
                  style: AppText.body(12, weight: FontWeight.w700)),
            ),
          ),
        ),
        Positioned(
          bottom: -6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Jun', 'Jul', 'Aug', 'Sep', 'Oct'].map((m) {
              final hot = m == 'Aug';
              return Text(m,
                  style: AppText.body(11,
                      weight: hot ? FontWeight.w600 : FontWeight.w400,
                      color: hot ? Colors.white : AppColors.white(0.45)));
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height - 24;
    // normalized points (x 0..1, y value 0..1 where 1 is top)
    final pts = const [
      Offset(0.02, 0.30), Offset(0.22, 0.42), Offset(0.41, 0.36),
      Offset(0.50, 0.78), Offset(0.68, 0.52), Offset(0.88, 0.82),
      Offset(0.98, 0.62),
    ];
    final path = Path();
    final scaled = pts
        .map((p) => Offset(p.dx * w, h - p.dy * (h - 20) + 10))
        .toList();
    path.moveTo(scaled.first.dx, scaled.first.dy);
    for (var i = 1; i < scaled.length; i++) {
      path.lineTo(scaled[i].dx, scaled[i].dy);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(colors: [
        AppColors.orange,
        AppColors.lime,
        AppColors.purpleLight,
      ]).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, line);

    // fill
    final fill = Path.from(path)
      ..lineTo(scaled.last.dx, h + 10)
      ..lineTo(scaled.first.dx, h + 10)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lime.withValues(alpha: 0.25), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // peak dot
    final peak = scaled[3];
    canvas.drawCircle(peak, 6, Paint()..color = AppColors.lime);
    canvas.drawCircle(peak, 6, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF0D0A16));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

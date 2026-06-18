import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/alter_lens_controller.dart';
import '../domain/alter_lens_models.dart';

class AlterLensScreen extends ConsumerWidget {
  const AlterLensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alterLensControllerProvider);
    final controller = ref.read(alterLensControllerProvider.notifier);
    final theme = Theme.of(context);
    final result = state.result;

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Alter Lens',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Camera intelligence for resumes, decks, posters, papers, and products.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in LensScanType.values)
                PremiumChip(
                  label: type.label,
                  selected: state.scanType == type,
                  icon: _scanIcon(type),
                  onTap: state.isAnalyzing
                      ? null
                      : () => controller.selectScanType(type),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              GlassPanel(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: context.isCompact ? 390 : 460,
                  child: _LensCameraPanel(
                    scanType: state.scanType,
                    isAnalyzing: state.isAnalyzing,
                    onCaptured: (capture) {
                      controller.analyzeCapture(
                        imageBytes: capture.bytes,
                        filename: capture.filename,
                        userContext: 'Mobile Alter Lens camera scan.',
                      );
                    },
                  ),
                ),
              ),
              MetricTile(
                label: 'Confidence',
                value: result == null
                    ? '--'
                    : '${(result.confidence * 100).round()}%',
                icon: LucideIcons.scan_eye,
                accent: AlterPalette.iris,
              ),
              MetricTile(
                label: 'Opportunities',
                value: '${result?.opportunities.length ?? 0}',
                icon: LucideIcons.radar,
                accent: AlterPalette.cyan,
              ),
              MetricTile(
                label: 'Recommendations',
                value: '${result?.recommendations.length ?? 0}',
                icon: LucideIcons.route,
                accent: AlterPalette.aura,
              ),
            ],
          ),
          if (state.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 18),
            _StatusPanel(message: state.errorMessage),
          ],
          if (state.isAnalyzing) ...[
            const SizedBox(height: 18),
            const _AnalyzingPanel(),
          ],
          if (result != null) ...[
            const SizedBox(height: 18),
            _SummaryPanel(result: result),
            const SizedBox(height: 18),
            ResponsiveGrid(
              mediumColumns: 2,
              expandedColumns: 3,
              children: [
                for (final insight in result.insights)
                  _InsightCard(insight: insight),
              ],
            ),
            const SizedBox(height: 18),
            ResponsiveGrid(
              mediumColumns: 2,
              expandedColumns: 2,
              children: [
                _OpportunityPanel(opportunities: result.opportunities),
                _RecommendationPanel(recommendations: result.recommendations),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LensCameraPanel extends StatefulWidget {
  const _LensCameraPanel({
    required this.scanType,
    required this.isAnalyzing,
    required this.onCaptured,
  });

  final LensScanType scanType;
  final bool isAnalyzing;
  final ValueChanged<_CapturedLensImage> onCaptured;

  @override
  State<_LensCameraPanel> createState() => _LensCameraPanelState();
}

class _LensCameraPanelState extends State<_LensCameraPanel>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _initialization;
  String _cameraError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialization = _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        _initialization = _initializeCamera();
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera is available on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraError = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = 'Camera is unavailable: $error';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        widget.isAnalyzing) {
      return;
    }
    final file = await controller.takePicture();
    final bytes = await file.readAsBytes();
    widget.onCaptured(
      _CapturedLensImage(
        bytes: bytes,
        filename: file.name.isEmpty ? 'alter-lens.jpg' : file.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        final controller = _cameraController;
        final hasCamera =
            controller != null &&
            controller.value.isInitialized &&
            _cameraError.isEmpty;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasCamera)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(controller),
              )
            else
              _CameraFallback(
                message: snapshot.connectionState == ConnectionState.waiting
                    ? 'Initializing camera'
                    : _cameraError,
              ),
            Positioned.fill(child: CustomPaint(painter: _LensOverlayPainter())),
            Positioned(
              left: 18,
              right: 18,
              top: 18,
              child: Row(
                children: [
                  PremiumChip(
                    label: widget.scanType.label,
                    selected: true,
                    icon: _scanIcon(widget.scanType),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasCamera
                          ? 'Frame the ${widget.scanType.label.toLowerCase()}'
                          : 'Enable camera permission to analyze a real capture',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CaptureButton(
                    enabled: hasCamera && !widget.isAnalyzing,
                    isAnalyzing: widget.isAnalyzing,
                    onPressed: _capture,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AlterPalette.ink.withValues(alpha: 0.98),
            AlterPalette.iris.withValues(alpha: 0.58),
            AlterPalette.cyan.withValues(alpha: 0.34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.camera, color: Colors.white, size: 44),
              const SizedBox(height: 12),
              Text(
                message.isEmpty ? 'Camera unavailable' : message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.enabled,
    required this.isAnalyzing,
    required this.onPressed,
  });

  final bool enabled;
  final bool isAnalyzing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AlterPalette.premiumGradient : null,
        color: enabled ? null : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        tooltip: 'Capture',
        color: Colors.white,
        onPressed: enabled ? onPressed : null,
        icon: isAnalyzing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Icon(LucideIcons.scan_line),
      ),
    );
  }
}

class _LensOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    for (var y = 28.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const length = 34.0;
    const inset = 22.0;
    final points = [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];

    canvas.drawLine(
      points[0],
      points[0] + const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      points[0],
      points[0] + const Offset(0, length),
      cornerPaint,
    );
    canvas.drawLine(
      points[1],
      points[1] - const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      points[1],
      points[1] + const Offset(0, length),
      cornerPaint,
    );
    canvas.drawLine(
      points[2],
      points[2] + const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      points[2],
      points[2] - const Offset(0, length),
      cornerPaint,
    );
    canvas.drawLine(
      points[3],
      points[3] - const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      points[3],
      points[3] - const Offset(0, length),
      cornerPaint,
    );

    final pulse = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AlterPalette.cyan.withValues(alpha: 0.26);
    final radius = math.min(size.width, size.height) * 0.28;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, pulse);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderOpacity: 0.5,
      child: Row(
        children: [
          const Icon(LucideIcons.shield_alert, color: AlterPalette.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AlterPalette.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingPanel extends StatelessWidget {
  const _AnalyzingPanel();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'OpenAI vision is extracting summary, insights, opportunities, and recommendations.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.result});

  final LensScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Summary',
            subtitle: result.detectedType,
            trailing: PremiumChip(
              label: '${(result.confidence * 100).round()}%',
              selected: true,
              icon: LucideIcons.scan_eye,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            result.summary,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          if (result.memoryCandidates.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final memory in result.memoryCandidates)
                  PremiumChip(label: memory),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).moveY(begin: 10, end: 0);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final LensInsightSignal insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  insight.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumChip(
                label: '${(insight.confidence * 100).round()}%',
                selected: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.detail,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in insight.tags) PremiumChip(label: tag)],
          ),
        ],
      ),
    );
  }
}

class _OpportunityPanel extends StatelessWidget {
  const _OpportunityPanel({required this.opportunities});

  final List<LensOpportunity> opportunities;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Opportunities',
            subtitle: 'What this scan unlocks now.',
          ),
          const SizedBox(height: 14),
          for (final opportunity in opportunities)
            _OpportunityRow(opportunity: opportunity),
        ],
      ),
    );
  }
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({required this.opportunity});

  final LensOpportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumChip(
            label: opportunity.score.round().toString(),
            selected: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opportunity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  opportunity.whyNow,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 5),
                Text(
                  opportunity.nextStep,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AlterPalette.iris,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.recommendations});

  final List<LensRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Recommendations',
            subtitle: 'Concrete next moves for ALTER.',
          ),
          const SizedBox(height: 14),
          for (final recommendation in recommendations)
            _RecommendationRow(recommendation: recommendation),
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.recommendation});

  final LensRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _priorityIcon(recommendation.priority),
            color: _priorityColor(recommendation.priority),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.action,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  recommendation.rationale,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 8),
                PremiumChip(
                  label: recommendation.priority.label,
                  selected:
                      recommendation.priority == LensPriority.high ||
                      recommendation.priority == LensPriority.urgent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturedLensImage {
  const _CapturedLensImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

IconData _scanIcon(LensScanType type) {
  return switch (type) {
    LensScanType.resume => LucideIcons.file_user,
    LensScanType.startupDeck => LucideIcons.presentation,
    LensScanType.eventPoster => LucideIcons.calendar_days,
    LensScanType.researchPaper => LucideIcons.file_text,
    LensScanType.product => LucideIcons.box,
  };
}

IconData _priorityIcon(LensPriority priority) {
  return switch (priority) {
    LensPriority.low => LucideIcons.circle,
    LensPriority.medium => LucideIcons.route,
    LensPriority.high => LucideIcons.zap,
    LensPriority.urgent => LucideIcons.flame,
  };
}

Color _priorityColor(LensPriority priority) {
  return switch (priority) {
    LensPriority.low => AlterPalette.slate,
    LensPriority.medium => AlterPalette.cyan,
    LensPriority.high => AlterPalette.iris,
    LensPriority.urgent => AlterPalette.danger,
  };
}

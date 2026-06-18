import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/gemma_model_config.dart';
import '../../../core/performance/on_device_resource_governor.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../ui/routes.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../application/gemma_model_manager.dart';

class EdgeModelScreen extends ConsumerStatefulWidget {
  const EdgeModelScreen({super.key});

  @override
  ConsumerState<EdgeModelScreen> createState() => _EdgeModelScreenState();
}

class _EdgeModelScreenState extends ConsumerState<EdgeModelScreen> {
  final _url = TextEditingController(text: kDefaultGemma4Url);
  String _selectedPreset = 'e4b';

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    await ref.read(gemmaModelProvider.notifier).download(
          url: _url.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gemma = ref.watch(gemmaModelProvider);
    final notifier = ref.read(gemmaModelProvider.notifier);
    final snapshot = ref.watch(resourceSnapshotProvider);

    return AmbientScaffold(
      scrollable: true,
      header: ShellPageHeader(
        title: 'EDGE',
        subtitle:
            'On-device Gemma 4 for Edge analysis. LiteRT .litertlm — ~3 GB, no token.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveGrid(
            children: [
              StatCard(
                label: 'Gemma status',
                value: gemma.statusLabel,
                icon: LucideIcons.cpu,
                accent: _statusAccent(gemma.status),
              ),
              StatCard(
                label: 'In RAM',
                value: gemma.isReady ? 'Yes' : 'No',
                icon: LucideIcons.memory_stick,
                accent: AlterPalette.cyan,
              ),
              StatCard(
                label: 'Device tier',
                value: snapshot.tier.name,
                icon: LucideIcons.smartphone,
                accent: AlterPalette.iris,
              ),
              StatCard(
                label: 'Est. RAM',
                value: '~${snapshot.estimatedRamMb} MB',
                icon: LucideIcons.activity,
                accent: AlterPalette.violet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionKicker(
            title: 'Model',
            subtitle: gemma.modelOnDisk
                ? 'Gemma is on disk.'
                : 'Download to enable full Edge analysis.',
          ),
          const SizedBox(height: 10),
          if (gemma.status == GemmaStatus.downloading)
            _ProgressCard(
              title: 'Downloading Gemma 4…',
              progress: gemma.progress,
              hint: 'Keep the app open — ~3 GB on Wi‑Fi.',
            )
          else if (gemma.status == GemmaStatus.loading ||
              gemma.status == GemmaStatus.checking)
            _ProgressCard(
              title: gemma.status == GemmaStatus.checking
                  ? 'Checking…'
                  : 'Loading into RAM…',
              progress: null,
              hint: gemma.message.isNotEmpty
                  ? gemma.message
                  : 'First load can take 5–15 minutes.',
            )
          else if (gemma.status == GemmaStatus.ready)
            _ReadyCard(onRemove: notifier.remove)
          else if (gemma.status == GemmaStatus.installed ||
              (gemma.status == GemmaStatus.error && gemma.modelOnDisk))
            _InstalledCard(
              onLoad: notifier.loadIntoRam,
              onRemove: notifier.remove,
            )
          else if (gemma.status == GemmaStatus.unsupported)
            GlassPanel(
              child: Text(
                'Gemma 4 runs on the Android/iOS build. Web uses pattern check only.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            _DownloadCard(
              urlController: _url,
              selectedPreset: _selectedPreset,
              onPreset: (preset, url) {
                setState(() {
                  _selectedPreset = preset;
                  _url.text = url;
                });
              },
              onDownload: _download,
              errorMessage:
                  gemma.status == GemmaStatus.error ? gemma.message : null,
            ),
        ],
      ),
    );
  }

  Color _statusAccent(GemmaStatus status) => switch (status) {
        GemmaStatus.ready => AlterPalette.mint,
        GemmaStatus.installed => AlterPalette.amber,
        GemmaStatus.downloading => AlterPalette.cyan,
        GemmaStatus.loading => AlterPalette.cyan,
        GemmaStatus.checking => AlterPalette.iris,
        GemmaStatus.unsupported => AlterPalette.amber,
        GemmaStatus.error => AlterPalette.danger,
        GemmaStatus.notInstalled => AlterPalette.amber,
      };
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.urlController,
    required this.selectedPreset,
    required this.onPreset,
    required this.onDownload,
    this.errorMessage,
  });

  final TextEditingController urlController;
  final String selectedPreset;
  final void Function(String preset, String url) onPreset;
  final VoidCallback onDownload;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download Gemma 4',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Public HuggingFace build — no token. Needs ~3 GB storage and '
            '8 GB+ RAM recommended for E4B.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: urlController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Model .litertlm URL',
              prefixIcon: Icon(LucideIcons.link, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip(
                label: 'E4B (default)',
                selected: selectedPreset == 'e4b',
                onTap: () => onPreset('e4b', kGemma4E4BLitertLmUrl),
              ),
              PillChip(
                label: 'E2B (smaller)',
                selected: selectedPreset == 'e2b',
                onTap: () => onPreset('e2b', kGemma4E2BLitertLmUrl),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LimeButton(
            label: 'Download & load',
            trailing: LucideIcons.download,
            height: 52,
            onTap: onDownload,
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InstalledCard extends StatelessWidget {
  const _InstalledCard({required this.onLoad, required this.onRemove});

  final VoidCallback onLoad;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemma 4 downloaded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Model is on disk but not in RAM. Edge uses pattern check until loaded.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          LimeButton(
            label: 'Load into RAM',
            trailing: LucideIcons.cpu,
            height: 52,
            onTap: onLoad,
          ),
          const SizedBox(height: 10),
          OutlineButton2(
            label: 'Remove model',
            height: 48,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.circle_check, color: AlterPalette.mint, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gemma 4 is active',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Edge analysis uses the real on-device model.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          OutlineButton2(
            label: 'Remove model',
            height: 48,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.hint,
    this.progress,
  });

  final String title;
  final String hint;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = progress != null && progress! > 0
        ? '${(progress! * 100).round()}%'
        : null;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (pct != null)
                Text(
                  pct,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AlterPalette.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress == null || progress == 0 ? null : progress,
            minHeight: 8,
            backgroundColor: AppColors.white(0.08),
            color: AlterPalette.cyan,
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

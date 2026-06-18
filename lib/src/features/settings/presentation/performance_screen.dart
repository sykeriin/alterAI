import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/performance/on_device_resource_governor.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../contextos/application/gemma_model_manager.dart';
import '../../voice/application/voice_io_preference.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';

class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(resourceSnapshotProvider);
    final gemma = ref.watch(gemmaModelProvider);

    return DeepScaffold(
      title: 'PERFORMANCE',
      subtitle: 'Device tier, RAM budget, and voice model policy.',
      child: ListView(
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('Device tier', snapshot.tier.name),
                _Row('Gemma 4 status', gemma.statusLabel),
                _Row('Gemma in RAM', gemma.isReady ? 'Yes' : 'No'),
                _Row('Loaded now', _leaseLabel(snapshot.loadedLease)),
                _Row('Est. model RAM', '~${snapshot.estimatedRamMb} MB'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice I/O mode',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<VoiceIoMode>(
                  segments: VoiceIoMode.values
                      .map(
                        (m) => ButtonSegment(
                          value: m,
                          label: Text(
                            switch (m) {
                              VoiceIoMode.offlineFirst => 'Offline first',
                              VoiceIoMode.cloudPreferred => 'Cloud first',
                              VoiceIoMode.offlineOnly => 'Offline only',
                            },
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                  selected: {ref.watch(voiceIoPreferenceProvider)},
                  onSelectionChanged: (s) => ref
                      .read(voiceIoPreferenceProvider.notifier)
                      .set(s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  'Offline first: sherpa ASR/TTS when downloaded. '
                  'Offline only: no cloud voice or STT fallback.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlterPalette.mint.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Keep Gemma loaded in RAM'),
            subtitle: const Text(
              'Stays ready when you leave the app. Uses ~3 GB RAM while active.',
            ),
            value: ref.watch(keepGemmaInRamProvider),
            onChanged: (v) =>
                ref.read(keepGemmaInRamProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: const Text('Unload models when app backgrounds'),
            subtitle: const Text(
              'Frees RAM when you switch away. Gemma is kept if the toggle above is on.',
            ),
            value: ref.watch(unloadOnBackgroundProvider),
            onChanged: (v) =>
                ref.read(unloadOnBackgroundProvider.notifier).set(v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Cloud AI enabled (OpenAI BYOK)'),
            value: ref.watch(cloudAiEnabledProvider),
            onChanged: (v) =>
                ref.read(cloudAiEnabledProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: const Text('Cloud voice enabled (Sarvam)'),
            value: ref.watch(cloudVoiceEnabledProvider),
            onChanged: (v) =>
                ref.read(cloudVoiceEnabledProvider.notifier).set(v),
          ),
          const SizedBox(height: 12),
          PremiumButton(
            label: 'On-device Gemma 4',
            icon: LucideIcons.cpu,
            onPressed: () => context.push(AlterRoutes.edge),
          ),
          if (gemma.status == GemmaStatus.installed ||
              (gemma.status == GemmaStatus.error && gemma.modelOnDisk))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PremiumButton(
                label: 'Load Gemma into RAM',
                icon: LucideIcons.play,
                onPressed: () =>
                    ref.read(gemmaModelProvider.notifier).loadIntoRam(),
              ),
            ),
          if (gemma.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PremiumButton(
                label: 'Unload Gemma from RAM',
                icon: LucideIcons.pause,
                onPressed: () =>
                    ref.read(gemmaModelProvider.notifier).unloadFromRam(),
              ),
            ),
          const SizedBox(height: 10),
          PremiumButton(
            label: 'Offline voice models',
            icon: LucideIcons.audio_lines,
            onPressed: () => context.push(AlterRoutes.offlineVoiceModels),
          ),
        ],
      ),
    );
  }
}

String _leaseLabel(String lease) => switch (lease) {
      'asr' => 'Speech recognition',
      'tts' => 'Text to speech',
      'llm' => 'On-device Gemma',
      'embedder' => 'Embeddings',
      'none' => 'None',
      _ => lease,
    };

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(color: AlterPalette.mint)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/performance/on_device_resource_governor.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../data/offline/offline_voice_config.dart';
import '../data/offline/offline_voice_model_manager.dart';

class OfflineVoiceModelsScreen extends ConsumerWidget {
  const OfflineVoiceModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineVoiceModelManagerProvider);
    final tier = ref.watch(deviceTierProvider);
    final manager = ref.read(offlineVoiceModelManagerProvider.notifier);
    final hasEnIn = state.installedTtsIds.contains(kTtsPiperEnInBundle.id);
    final hasHi = state.installedTtsIds.contains(kTtsPiperHiBundle.id);

    return DeepScaffold(
      title: 'OFFLINE VOICE',
      subtitle:
          'Speech recognition and text-to-speech for airplane-mode voice. '
          'Device tier: ${tier.name}.',
      child: ListView(
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow(
                  label: 'Speech recognition',
                  ready: state.isAsrReady,
                  detail: state.installedAsrId.isEmpty
                      ? 'Not downloaded'
                      : state.installedAsrId,
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Text to speech',
                  ready: state.isTtsReady,
                  detail: state.installedTtsIds.isEmpty
                      ? 'Not downloaded'
                      : state.installedTtsIds.join(', '),
                ),
                if (state.message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(state.message),
                ],
                if (state.status == OfflineVoiceStatus.downloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: state.progress),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: state.isAsrReady
                ? 'Re-download speech recognition'
                : 'Download speech recognition (${asrBundleForTier(tier).approxMb} MB)',
            icon: LucideIcons.mic,
            onPressed: state.status == OfflineVoiceStatus.downloading
                ? null
                : () => manager.downloadAsrBundle(tier: tier),
          ),
          const SizedBox(height: 10),
          PremiumButton(
            label: hasEnIn
                ? 'Re-download en-IN voice'
                : 'Download en-IN voice (${kTtsPiperEnInBundle.approxMb} MB)',
            icon: LucideIcons.volume_2,
            onPressed: state.status == OfflineVoiceStatus.downloading
                ? null
                : () => manager.downloadTtsBundle('en-IN'),
          ),
          const SizedBox(height: 10),
          PremiumButton(
            label: hasHi
                ? 'Re-download Hindi voice'
                : 'Download Hindi voice (${kTtsPiperHiBundle.approxMb} MB)',
            icon: LucideIcons.languages,
            onPressed: state.status == OfflineVoiceStatus.downloading
                ? null
                : () => manager.downloadTtsBundle('hi'),
          ),
          const SizedBox(height: 10),
          PremiumButton(
            label: 'Uninstall all voice models',
            icon: LucideIcons.trash_2,
            onPressed: state.status == OfflineVoiceStatus.downloading
                ? null
                : () => manager.uninstallAll(),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ready,
    required this.detail,
  });

  final String label;
  final bool ready;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ready ? LucideIcons.circle_check : LucideIcons.circle_dashed,
          color: ready ? AlterPalette.mint : AlterPalette.amber,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                detail,
                style: TextStyle(
                  color: AppColors.white(0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

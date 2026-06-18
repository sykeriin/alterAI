import '../../../../core/performance/device_tier.dart';

/// HuggingFace / sherpa-onnx release URLs for on-demand download.
class OfflineVoiceBundle {
  const OfflineVoiceBundle({
    required this.id,
    required this.label,
    required this.archiveUrl,
    required this.approxMb,
    required this.tiers,
  });

  final String id;
  final String label;
  final String archiveUrl;
  final int approxMb;
  final Set<DeviceTier> tiers;
}

/// SenseVoice multilingual ASR + Silero VAD (Mid+ default).
const kAsrSenseVoiceBundle = OfflineVoiceBundle(
  id: 'asr_sensevoice',
  label: 'SenseVoice ASR + VAD',
  archiveUrl:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09.tar.bz2',
  approxMb: 240,
  tiers: {DeviceTier.mid, DeviceTier.high},
);

/// Moonshine Tiny English ASR (Low tier).
const kAsrMoonshineBundle = OfflineVoiceBundle(
  id: 'asr_moonshine',
  label: 'Moonshine Tiny ASR (English)',
  archiveUrl:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-moonshine-tiny-en-int8.tar.bz2',
  approxMb: 130,
  tiers: {DeviceTier.low},
);

const kVadSileroUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';

const kTtsPiperEnInBundle = OfflineVoiceBundle(
  id: 'tts_en_in',
  label: 'Piper en-IN (Pratham)',
  archiveUrl:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_IN-pratham-medium.tar.bz2',
  approxMb: 20,
  tiers: {DeviceTier.mid, DeviceTier.high, DeviceTier.low},
);

const kTtsPiperHiBundle = OfflineVoiceBundle(
  id: 'tts_hi',
  label: 'Piper Hindi',
  archiveUrl:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-hi_IN-rohan-medium.tar.bz2',
  approxMb: 25,
  tiers: {DeviceTier.mid, DeviceTier.high},
);

OfflineVoiceBundle asrBundleForTier(DeviceTier tier) => switch (tier) {
      DeviceTier.low => kAsrMoonshineBundle,
      _ => kAsrSenseVoiceBundle,
    };

String ttsBundleIdForLocale(String locale) {
  final normalized = locale.toLowerCase();
  if (normalized.startsWith('hi')) return kTtsPiperHiBundle.id;
  return kTtsPiperEnInBundle.id;
}

OfflineVoiceBundle ttsBundleForLocale(String locale) {
  final normalized = locale.toLowerCase();
  if (normalized.startsWith('hi')) return kTtsPiperHiBundle;
  return kTtsPiperEnInBundle;
}

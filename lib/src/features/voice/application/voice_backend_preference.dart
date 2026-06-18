import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceBackend {
  onDevice,
  cloudAi,
  gateway,
}

extension VoiceBackendLabels on VoiceBackend {
  String get label => switch (this) {
        VoiceBackend.onDevice => 'Gemma on-device',
        VoiceBackend.cloudAi => 'Cloud AI',
        VoiceBackend.gateway => 'ALTER Gateway',
      };

  String get description => switch (this) {
        VoiceBackend.onDevice =>
          'Gemma 4 on your phone — private, offline actions and conversation.',
        VoiceBackend.cloudAi =>
          'OpenAI via your API key — optional cloud fallback.',
        VoiceBackend.gateway =>
          'ALTER cloud runtime — actions, intents, and memory sync.',
      };
}

String voiceBackendSubtitle(VoiceBackend backend) => switch (backend) {
      VoiceBackend.onDevice => 'Gemma 4 on-device',
      VoiceBackend.cloudAi => 'Cloud AI · OpenAI',
      VoiceBackend.gateway => 'ALTER Gateway',
    };

const _prefsKey = 'alter_voice_backend';

class VoiceBackendPreference extends Notifier<VoiceBackend> {
  @override
  VoiceBackend build() {
    _load();
    return VoiceBackend.onDevice;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    if (raw == 'onDevice') {
      state = VoiceBackend.onDevice;
      return;
    }
    for (final b in VoiceBackend.values) {
      if (b.name == raw) {
        state = b;
        return;
      }
    }
  }

  Future<void> set(VoiceBackend backend) async {
    state = backend;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, backend.name);
  }
}

final voiceBackendPreferenceProvider =
    NotifierProvider<VoiceBackendPreference, VoiceBackend>(
  VoiceBackendPreference.new,
);

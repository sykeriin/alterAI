import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceIoMode { offlineFirst, cloudPreferred, offlineOnly }

extension VoiceIoModeLabels on VoiceIoMode {
  String get label => switch (this) {
        VoiceIoMode.offlineFirst => 'Offline first',
        VoiceIoMode.cloudPreferred => 'Cloud preferred',
        VoiceIoMode.offlineOnly => 'Offline only',
      };
}

const _ioModeKey = 'alter_voice_io_mode';
const _cloudAiKey = 'alter_cloud_ai_enabled';
const _cloudVoiceKey = 'alter_cloud_voice_enabled';
const _wifiOnlyKey = 'alter_model_wifi_only';
const _unloadBackgroundKey = 'alter_unload_on_background';
const _keepGemmaInRamKey = 'alter_keep_gemma_in_ram';

class VoiceIoPreference extends Notifier<VoiceIoMode> {
  @override
  VoiceIoMode build() {
    _load();
    return VoiceIoMode.offlineFirst;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ioModeKey);
    for (final mode in VoiceIoMode.values) {
      if (mode.name == raw) {
        state = mode;
        return;
      }
    }
  }

  Future<void> set(VoiceIoMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ioModeKey, mode.name);
  }
}

final voiceIoPreferenceProvider =
    NotifierProvider<VoiceIoPreference, VoiceIoMode>(VoiceIoPreference.new);

class CloudAiEnabled extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cloudAiKey)) {
      state = prefs.getBool(_cloudAiKey) ?? true;
    }
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudAiKey, enabled);
  }
}

final cloudAiEnabledProvider =
    NotifierProvider<CloudAiEnabled, bool>(CloudAiEnabled.new);

class CloudVoiceEnabled extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cloudVoiceKey)) {
      state = prefs.getBool(_cloudVoiceKey) ?? true;
    }
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudVoiceKey, enabled);
  }
}

final cloudVoiceEnabledProvider =
    NotifierProvider<CloudVoiceEnabled, bool>(CloudVoiceEnabled.new);

class ModelDownloadPolicy extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_wifiOnlyKey)) {
      state = prefs.getBool(_wifiOnlyKey) ?? true;
    }
  }

  Future<void> setWifiOnly(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }
}

final modelDownloadWifiOnlyProvider =
    NotifierProvider<ModelDownloadPolicy, bool>(ModelDownloadPolicy.new);

class UnloadOnBackgroundPreference extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_unloadBackgroundKey)) {
      state = prefs.getBool(_unloadBackgroundKey) ?? true;
    }
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unloadBackgroundKey, value);
  }
}

final unloadOnBackgroundProvider =
    NotifierProvider<UnloadOnBackgroundPreference, bool>(
  UnloadOnBackgroundPreference.new,
);

/// When true, Gemma stays in RAM across app backgrounding and idle periods.
class KeepGemmaInRamPreference extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keepGemmaInRamKey)) {
      state = prefs.getBool(_keepGemmaInRamKey) ?? true;
    }
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepGemmaInRamKey, value);
  }
}

final keepGemmaInRamProvider =
    NotifierProvider<KeepGemmaInRamPreference, bool>(
  KeepGemmaInRamPreference.new,
);

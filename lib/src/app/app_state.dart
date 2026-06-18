import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/backend/application/backend_config_controller.dart';
import '../features/backend/data/backend_api_client.dart';

const _themeModeKey = 'alter.app.theme_mode';
const _selectedLanguageKey = 'alter.app.selected_language';
const _cameraModeKey = 'alter.app.camera_mode';
const _privacyShieldKey = 'alter.app.privacy_shield';
const _proactiveBriefsKey = 'alter.app.proactive_briefs';
const _voiceListeningKey = 'alter.app.voice_listening';
const _onDeviceModeKey = 'alter.app.on_device_mode';

class AlterAppState {
  const AlterAppState({
    required this.onboardingComplete,
    required this.themeMode,
    required this.voiceListening,
    required this.selectedLanguage,
    required this.cameraMode,
    required this.privacyShield,
    required this.proactiveBriefs,
    required this.onDeviceMode,
  });

  factory AlterAppState.initial() {
    return const AlterAppState(
      onboardingComplete: false,
      themeMode: ThemeMode.system,
      voiceListening: false,
      selectedLanguage: 'English',
      cameraMode: 'Context',
      privacyShield: true,
      proactiveBriefs: true,
      onDeviceMode: false,
    );
  }

  final bool onboardingComplete;
  final ThemeMode themeMode;
  final bool voiceListening;
  final String selectedLanguage;
  final String cameraMode;
  final bool privacyShield;
  final bool proactiveBriefs;

  /// When true, plain conversational turns are answered fully on-device by the
  /// installed local model; the agent only reaches the cloud for tools or deep
  /// reasoning. No effect until a model is installed.
  final bool onDeviceMode;

  AlterAppState copyWith({
    bool? onboardingComplete,
    ThemeMode? themeMode,
    bool? voiceListening,
    String? selectedLanguage,
    String? cameraMode,
    bool? privacyShield,
    bool? proactiveBriefs,
    bool? onDeviceMode,
  }) {
    return AlterAppState(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      voiceListening: voiceListening ?? this.voiceListening,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      cameraMode: cameraMode ?? this.cameraMode,
      privacyShield: privacyShield ?? this.privacyShield,
      proactiveBriefs: proactiveBriefs ?? this.proactiveBriefs,
      onDeviceMode: onDeviceMode ?? this.onDeviceMode,
    );
  }
}

class AlterAppController extends Notifier<AlterAppState> {
  @override
  AlterAppState build() {
    Future.microtask(_loadPersistedState);
    return AlterAppState.initial();
  }

  void completeOnboarding() {
    state = state.copyWith(onboardingComplete: true);
    unawaited(_persistAndSync());
  }

  void setThemeMode(ThemeMode themeMode) {
    state = state.copyWith(themeMode: themeMode);
    unawaited(_persistAndSync());
  }

  void toggleListening() {
    state = state.copyWith(voiceListening: !state.voiceListening);
    unawaited(_persistAndSync());
  }

  void setVoiceListening(bool value) {
    state = state.copyWith(voiceListening: value);
    unawaited(_persistAndSync());
  }

  void setLanguage(String language) {
    state = state.copyWith(selectedLanguage: language);
    unawaited(_persistAndSync());
  }

  void setCameraMode(String mode) {
    state = state.copyWith(cameraMode: mode);
    unawaited(_persistAndSync());
  }

  void setPrivacyShield(bool value) {
    state = state.copyWith(privacyShield: value);
    unawaited(_persistAndSync());
  }

  void setProactiveBriefs(bool value) {
    state = state.copyWith(proactiveBriefs: value);
    unawaited(_persistAndSync());
  }

  void setOnDeviceMode(bool value) {
    state = state.copyWith(onDeviceMode: value);
    unawaited(_persistAndSync());
  }

  void toggleOnDeviceMode() => setOnDeviceMode(!state.onDeviceMode);

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeModeKey);
    state = state.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => state.themeMode,
      ),
      selectedLanguage:
          prefs.getString(_selectedLanguageKey) ?? state.selectedLanguage,
      cameraMode: prefs.getString(_cameraModeKey) ?? state.cameraMode,
      privacyShield: prefs.getBool(_privacyShieldKey) ?? state.privacyShield,
      proactiveBriefs:
          prefs.getBool(_proactiveBriefsKey) ?? state.proactiveBriefs,
      voiceListening: prefs.getBool(_voiceListeningKey) ?? state.voiceListening,
      onDeviceMode: prefs.getBool(_onDeviceModeKey) ?? state.onDeviceMode,
    );
  }

  Future<void> _persistAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, state.themeMode.name);
    await prefs.setString(_selectedLanguageKey, state.selectedLanguage);
    await prefs.setString(_cameraModeKey, state.cameraMode);
    await prefs.setBool(_privacyShieldKey, state.privacyShield);
    await prefs.setBool(_proactiveBriefsKey, state.proactiveBriefs);
    await prefs.setBool(_voiceListeningKey, state.voiceListening);
    await prefs.setBool(_onDeviceModeKey, state.onDeviceMode);
    await _syncBackendSettings();
  }

  Future<void> _syncBackendSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final config = await ref.read(backendConfigProvider.future);
    if (!config.hasGateway) return;
    final client = BackendApiClient(baseUrl: config.gatewayUrl);
    try {
      await client.patchJson('/v1/user/settings?user_id=$userId', {
        'languages': [state.selectedLanguage],
        'permissions': {
          'voice_listening': state.voiceListening,
          'privacy_shield': state.privacyShield,
          'proactive_briefs': state.proactiveBriefs,
          'camera_context': state.cameraMode.toLowerCase() == 'context',
        },
      });
    } catch (_) {
      // Settings are still persisted locally; backend sync retries on next change.
    } finally {
      client.close();
    }
  }
}

final alterAppControllerProvider =
    NotifierProvider<AlterAppController, AlterAppState>(AlterAppController.new);

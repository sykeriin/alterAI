import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_provider.dart';
import '../data/nfc_hce_bridge.dart';
import '../data/nfc_networking_gateway.dart';
import '../data/nfc_payload_codec.dart';
import '../domain/nfc_match.dart';
import '../domain/nfc_match_engine.dart';
import '../domain/nfc_profile.dart';

final localNfcProfileProvider = Provider<NfcProfile>((ref) {
  final profile = ref.watch(userProfileProvider).asData?.value;
  return NfcProfile(
    userId: profile?.id ?? '',
    displayName: profile?.displayName ?? '',
    role: profile?.role ?? '',
    portfolioUrl: '',
    resumeUrl: '',
    linkedinUrl: '',
    skills: profile?.skills ?? const <String>[],
    interests: profile?.interests ?? const <String>[],
    goals: profile?.goals ?? const <String>[],
    lookingFor: const <String>[],
    startupStage: profile?.careerStage ?? '',
    preferredHackathons: const <String>[],
    location: '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
});

final nfcNetworkingGatewayProvider = Provider<NfcNetworkingGateway>((ref) {
  return NfcManagerNetworkingGateway();
});

final nfcMatchEngineProvider = Provider<NfcMatchEngine>((ref) {
  return const NfcMatchEngine();
});

final nfcNetworkingControllerProvider =
    NotifierProvider<NfcNetworkingController, NfcNetworkingState>(
      NfcNetworkingController.new,
    );

class NfcNetworkingController extends Notifier<NfcNetworkingState> {
  @override
  NfcNetworkingState build() {
    return NfcNetworkingState(localProfile: ref.watch(localNfcProfileProvider));
  }

  Future<void> refreshAvailability() async {
    state = state.copyWith(
      phase: NfcNetworkingPhase.checking,
      errorMessage: '',
    );
    try {
      final availability = await ref
          .read(nfcNetworkingGatewayProvider)
          .checkAvailability();
      state = state.copyWith(
        phase: availability == AlterNfcAvailability.enabled
            ? NfcNetworkingPhase.idle
            : NfcNetworkingPhase.unavailable,
        availability: availability,
      );
    } catch (error) {
      state = state.copyWith(
        phase: NfcNetworkingPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> scanAndMatch() async {
    state = state.copyWith(
      phase: NfcNetworkingPhase.scanning,
      errorMessage: '',
    );
    try {
      final peer = await ref.read(nfcNetworkingGatewayProvider).scanProfile();
      final result = ref
          .read(nfcMatchEngineProvider)
          .evaluate(localProfile: state.localProfile, peerProfile: peer);
      state = state.copyWith(
        phase: NfcNetworkingPhase.matched,
        availability: AlterNfcAvailability.enabled,
        lastResult: result,
      );
    } catch (error) {
      state = state.copyWith(
        phase: NfcNetworkingPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> shareProfile() async {
    state = state.copyWith(phase: NfcNetworkingPhase.writing, errorMessage: '');
    try {
      await ref
          .read(nfcNetworkingGatewayProvider)
          .writeProfile(state.localProfile);
      state = state.copyWith(
        phase: NfcNetworkingPhase.idle,
        availability: AlterNfcAvailability.enabled,
      );
    } catch (error) {
      state = state.copyWith(
        phase: NfcNetworkingPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> stop() async {
    await ref.read(nfcNetworkingGatewayProvider).stop();
    state = state.copyWith(phase: NfcNetworkingPhase.idle);
  }

  /// Phone-to-phone: broadcast the profile over HCE so another ALTER phone can
  /// receive it by tapping (no physical tag needed).
  Future<void> shareViaTap() async {
    const bridge = NfcHceBridge();
    if (!await bridge.isSupported()) {
      state = state.copyWith(
        phase: NfcNetworkingPhase.error,
        errorMessage: 'This phone does not support NFC tap-to-share (HCE).',
      );
      return;
    }
    final json = jsonEncode(state.localProfile.toExchangePayload());
    final ok = await bridge.enableSharing(
      mimeType: NfcPayloadCodec.mimeType,
      json: json,
    );
    state = state.copyWith(
      phase: ok ? NfcNetworkingPhase.broadcasting : NfcNetworkingPhase.error,
      availability: ok ? AlterNfcAvailability.enabled : state.availability,
      errorMessage: ok ? '' : 'Could not start tap-to-share.',
    );
  }

  Future<void> stopTapShare() async {
    await const NfcHceBridge().disableSharing();
    state = state.copyWith(phase: NfcNetworkingPhase.idle);
  }
}

class NfcNetworkingState {
  const NfcNetworkingState({
    required this.localProfile,
    this.phase = NfcNetworkingPhase.idle,
    this.availability,
    this.lastResult,
    this.errorMessage = '',
  });

  final NfcProfile localProfile;
  final NfcNetworkingPhase phase;
  final AlterNfcAvailability? availability;
  final NfcExchangeResult? lastResult;
  final String errorMessage;

  bool get isBusy =>
      phase == NfcNetworkingPhase.checking ||
      phase == NfcNetworkingPhase.scanning ||
      phase == NfcNetworkingPhase.writing;

  NfcNetworkingState copyWith({
    NfcProfile? localProfile,
    NfcNetworkingPhase? phase,
    AlterNfcAvailability? availability,
    NfcExchangeResult? lastResult,
    String? errorMessage,
  }) {
    return NfcNetworkingState(
      localProfile: localProfile ?? this.localProfile,
      phase: phase ?? this.phase,
      availability: availability ?? this.availability,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum NfcNetworkingPhase {
  idle,
  checking,
  scanning,
  writing,
  broadcasting,
  matched,
  unavailable,
  error,
}

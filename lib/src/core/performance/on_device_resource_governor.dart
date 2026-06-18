import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_tier.dart';

enum OnDeviceResource { asr, tts, llm, embedder }

typedef ResourceDisposer = Future<void> Function();

/// Ensures ASR, TTS, and LLM are never loaded simultaneously on low-RAM devices.
class OnDeviceResourceGovernor extends Notifier<OnDeviceResource?> {
  final _disposers = <OnDeviceResource, ResourceDisposer>{};

  @override
  OnDeviceResource? build() => null;

  DeviceTier get tier => detectDeviceTier();

  void registerDisposer(OnDeviceResource resource, ResourceDisposer disposer) {
    _disposers[resource] = disposer;
  }

  Future<void> acquire(OnDeviceResource resource) async {
    final current = state;
    if (current != null && current != resource) {
      await release(current, unload: true);
    }
    state = resource;
  }

  Future<void> release(OnDeviceResource resource, {bool unload = true}) async {
    if (state != resource) return;
    if (unload) {
      final disposer = _disposers[resource];
      if (disposer != null) await disposer();
    }
    state = null;
  }

  Future<void> releaseAll({bool unload = true}) async {
    final current = state;
    if (current == null) return;
    await release(current, unload: unload);
  }

  ResourceSnapshot snapshot() {
    final lease = state;
    final ram = switch (lease) {
      OnDeviceResource.asr => tier == DeviceTier.low ? 150 : 380,
      OnDeviceResource.tts => 70,
      OnDeviceResource.llm => tier == DeviceTier.low ? 800 : 3200,
      OnDeviceResource.embedder => 180,
      null => 0,
    };
    return ResourceSnapshot(
      tier: tier,
      loadedLease: lease?.name ?? 'none',
      estimatedRamMb: ram,
    );
  }
}

final onDeviceResourceGovernorProvider =
    NotifierProvider<OnDeviceResourceGovernor, OnDeviceResource?>(
  OnDeviceResourceGovernor.new,
);

final resourceSnapshotProvider = Provider<ResourceSnapshot>((ref) {
  ref.watch(onDeviceResourceGovernorProvider);
  return ref.read(onDeviceResourceGovernorProvider.notifier).snapshot();
});

final deviceTierProvider = Provider<DeviceTier>((ref) => detectDeviceTier());

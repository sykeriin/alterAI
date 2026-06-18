import 'dart:io';

enum DeviceTier { low, mid, high }

DeviceTier detectDeviceTier() {
  if (!Platform.isAndroid && !Platform.isIOS) return DeviceTier.mid;
  // Heuristic until native RAM probe is wired; override in Settings → Performance.
  return DeviceTier.mid;
}

int maxTokensForTier(DeviceTier tier) => switch (tier) {
      DeviceTier.low => 512,
      DeviceTier.mid => 1024,
      DeviceTier.high => 2048,
    };

class ResourceSnapshot {
  const ResourceSnapshot({
    required this.tier,
    required this.loadedLease,
    required this.estimatedRamMb,
  });

  final DeviceTier tier;
  final String loadedLease;
  final int estimatedRamMb;
}

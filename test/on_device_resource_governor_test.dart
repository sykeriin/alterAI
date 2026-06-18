import 'package:alter/src/core/performance/on_device_resource_governor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acquire swaps resource and invokes previous disposer', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final gov = container.read(onDeviceResourceGovernorProvider.notifier);
    var asrDisposed = false;
    var ttsDisposed = false;

    gov.registerDisposer(OnDeviceResource.asr, () async {
      asrDisposed = true;
    });
    gov.registerDisposer(OnDeviceResource.tts, () async {
      ttsDisposed = true;
    });

    await gov.acquire(OnDeviceResource.asr);
    expect(container.read(onDeviceResourceGovernorProvider), OnDeviceResource.asr);

    await gov.acquire(OnDeviceResource.tts);
    expect(asrDisposed, isTrue);
    expect(container.read(onDeviceResourceGovernorProvider), OnDeviceResource.tts);

    await gov.release(OnDeviceResource.tts, unload: true);
    expect(ttsDisposed, isTrue);
    expect(container.read(onDeviceResourceGovernorProvider), isNull);
  });
}

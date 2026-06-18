import 'package:alter/src/features/permissions/data/permission_hub_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses permission status entries', () {
    final entry = PermissionStatusEntry.fromMap({
      'granted': true,
      'systemManaged': false,
    });

    expect(entry.granted, isTrue);
    expect(entry.systemManaged, isFalse);
  });
}

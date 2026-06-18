import 'package:alter/src/features/device_control/data/device_control_bridge.dart';
import 'package:alter/src/features/device_control/domain/phone_action_policy.dart';
import 'package:alter/src/features/device_control/domain/screen_understanding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses native device control result', () {
    final result = DeviceControlResult.fromMap({
      'ok': true,
      'message': 'Opened Android settings.',
    });

    expect(result.ok, isTrue);
    expect(result.message, 'Opened Android settings.');
  });

  test('parses device admin status', () {
    final status = DeviceAdminStatus.fromMap({
      'ok': true,
      'message': 'ALTER is Device Owner on this Android profile.',
      'adminActive': true,
      'deviceOwner': true,
      'profileOwner': false,
    });

    expect(status.ok, isTrue);
    expect(status.managed, isTrue);
    expect(status.deviceOwner, isTrue);
  });

  test('parses visible screen snapshot', () {
    final snapshot = DeviceScreenSnapshot.fromMap({
      'ok': true,
      'message': 'Read 1 visible nodes.',
      'packageName': 'com.example',
      'className': 'Root',
      'text': 'Continue',
      'nodes': [
        {
          'text': 'Continue',
          'className': 'android.widget.Button',
          'viewId': 'continue_button',
          'clickable': true,
          'editable': false,
          'scrollable': false,
          'bounds': {'left': 1, 'top': 2, 'right': 3, 'bottom': 4},
        },
      ],
    });

    expect(snapshot.ok, isTrue);
    expect(snapshot.nodes.single.text, 'Continue');
    expect(snapshot.nodes.single.clickable, isTrue);
  });

  test('classifies high-impact visible clicks as confirmation required', () {
    final policy = PhoneActionPolicy.classify(
      kind: 'click_text',
      target: 'Send money',
      requiresAccessibility: true,
    );

    expect(policy.risk, PhoneActionRisk.confirmationRequired);
    expect(policy.canExecuteOn(PhoneActionSurface.agentDirect), isFalse);
    expect(policy.canExecuteOn(PhoneActionSurface.openClawConfirmed), isTrue);
  });

  test('builds structured screen roles from visible nodes', () {
    final snapshot = DeviceScreenSnapshot.fromMap({
      'ok': true,
      'message': 'Read 2 visible nodes.',
      'packageName': 'com.example',
      'className': 'Root',
      'text': 'Name Continue',
      'nodes': [
        {
          'text': 'Name',
          'className': 'android.widget.EditText',
          'viewId': 'name_field',
          'clickable': true,
          'editable': true,
          'scrollable': false,
          'bounds': {'left': 0, 'top': 0, 'right': 200, 'bottom': 40},
        },
        {
          'text': 'Continue',
          'className': 'android.widget.Button',
          'viewId': 'continue_button',
          'clickable': true,
          'editable': false,
          'scrollable': false,
          'bounds': {'left': 0, 'top': 50, 'right': 200, 'bottom': 90},
        },
      ],
    });

    final structured = StructuredScreen.fromSnapshot(snapshot);

    expect(structured.inputs.single.text, 'Name');
    expect(structured.buttons.single.text, 'Continue');
    expect(structured.summary, contains('1 buttons'));
  });
}

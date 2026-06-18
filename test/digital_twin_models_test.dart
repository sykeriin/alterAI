import 'package:alter/src/features/contextos/domain/digital_twin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete twin preset activates every source locally first', () {
    final staged = DigitalTwinState.defaults().stageCompleteTwin();

    expect(staged.activeSourceCount, DigitalTwinSource.values.length);
    expect(staged.autonomyLevel, TwinAutonomyLevel.draft);
    expect(staged.readinessScore, greaterThan(0.75));
    expect(staged.localFullCount, greaterThanOrEqualTo(3));
    expect(staged.hardGuardrails.first, contains('No silent sends'));
  });

  test('turning a source off reduces readiness', () {
    final staged = DigitalTwinState.defaults().stageCompleteTwin();
    final withoutChats = staged.withSource(
      DigitalTwinSource.whatsapp,
      TwinAccessLevel.off,
    );

    expect(withoutChats.readinessScore, lessThan(staged.readinessScore));
    expect(
      withoutChats.consentFor(DigitalTwinSource.whatsapp).isActive,
      isFalse,
    );
  });
}

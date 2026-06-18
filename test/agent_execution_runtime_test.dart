import 'package:alter/src/features/agent/application/agent_execution_runtime.dart';
import 'package:alter/src/features/voice/data/sarvam_live_voice_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AgentRuntimeStep parses backend planner step', () {
    final step = AgentRuntimeStep.fromBackend(const <String, dynamic>{
      'tool_name': 'openclaw.accessibility_action',
      'title': 'Queue visible-screen action',
      'rationale': 'Needs Accessibility.',
      'parameters': <String, Object?>{'instruction': 'scroll down'},
      'requires_confirmation': true,
      'requires_accessibility': true,
      'status': 'planned',
    });

    expect(step.toolName, 'openclaw.accessibility_action');
    expect(step.agent, AgentSpecialist.phoneControl);
    expect(step.requiresAccessibility, isTrue);
    expect(step.status, AgentStepStatus.planned);
  });

  test('Sarvam live voice result parsers handle fallback', () {
    final stt = SarvamSttResult.fromJson(const <String, dynamic>{
      'provider': 'alter-local',
      'sarvam_enabled': false,
      'fallback': true,
      'transcript': '',
      'language_code': 'unknown',
      'error': 'SARVAM_API_KEY is not configured.',
    });

    final tts = SarvamTtsResult.fromJson(const <String, dynamic>{
      'provider': 'alter-local',
      'sarvam_enabled': false,
      'fallback': true,
      'audio_base64': '',
      'target_language_code': 'en-IN',
    });

    expect(stt.fallback, isTrue);
    expect(stt.error, contains('SARVAM_API_KEY'));
    expect(tts.audioBase64, isEmpty);
    expect(tts.targetLanguageCode, 'en-IN');
  });
}

import 'package:alter/src/features/voice/data/voice_runtime_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VoiceRuntimeResult parses action runtime response', () {
    final result = VoiceRuntimeResult.fromJson(const <String, dynamic>{
      'normalized_text': 'should I build ALTER into a startup?',
      'wake_word_detected': true,
      'inferred_intent': 'future_decision',
      'intent_confidence': 0.92,
      'spoken_response': 'I recommend a validation sprint.',
      'display_response': 'I recommend a validation sprint.\nDeadline: Friday',
      'ai_provider': 'sarvam',
      'source_language_code': 'en-IN',
      'response_language_code': 'hi-IN',
      'language_display_name': 'Hindi',
      'action_graph': <String>[
        'Capture transcript',
        'Retrieve personal memory',
        'Create experiment plan',
      ],
      'experiment_plan': <String, dynamic>{
        'action': 'Interview five target users.',
        'why_it_matters': 'This tests demand.',
        'deadline': '2026-06-19',
        'success_metric': 'Five interviews and two beta requests.',
      },
      'next_actions': <String>['Interview five target users.'],
      'follow_up_questions': <String>['Did you do the experiment?'],
      'signals': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'Wake Word + Intent Runtime',
          'status': 'ok',
          'summary': 'Intent=future_decision wake=True.',
          'latency_ms': 42,
        },
      ],
    });

    expect(result.wakeWordDetected, isTrue);
    expect(result.inferredIntent, 'future_decision');
    expect(result.aiProvider, 'sarvam');
    expect(result.responseLanguageCode, 'hi-IN');
    expect(result.experimentPlan?.action, contains('Interview'));
    expect(result.signals.single.isHealthy, isTrue);
  });
}

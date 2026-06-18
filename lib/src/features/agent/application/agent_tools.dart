import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/application/backend_config_controller.dart';
import '../../backend/application/feature_live_providers.dart';
import '../../backend/application/life_os_providers.dart';
import '../../backend/data/backend_api_client.dart';
import '../../context/data/on_device_context.dart';
import '../../contextos/application/daytwin_controller.dart';
import '../../contextos/application/decision_council_controller.dart';
import '../../contextos/application/decision_dna_controller.dart';
import '../../contextos/application/futuretwin_controller.dart';
import '../../contextos/application/lifeshield_controller.dart';
import '../../contextos/application/memory_engine.dart';
import '../../contextos/application/openclaw_adapter.dart';
import '../../contextos/domain/contextos_models.dart';
import '../../device_control/application/phone_control_controller.dart';
import '../../feedback/application/feedback_log.dart';
import '../../feedback/domain/feedback_event.dart';
import '../../privacy/data/context_privacy_filter.dart';
import '../../social/application/social_graph_service.dart';
import '../data/device_actions.dart';
import 'agent_execution_runtime.dart';
import 'notification_monitor.dart';
import 'persistent_intelligence_store.dart';

/// OpenAI tool schemas the agent can call. Engine tools route to the ContextOS
/// engines; device tools launch permissioned OS surfaces the user confirms.
const kAgentTools = <Map<String, dynamic>>[
  {
    'type': 'function',
    'function': {
      'name': 'find_opportunities',
      'description':
          'Find real opportunities (hackathons, internships, grants, open-source, '
              'roles) matched to the user\'s profile via the Opportunity Radar.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'read_life_feed',
      'description':
          'Read the user\'s live day feed — greeting, today\'s focus, and the '
              'tasks that need them. Use for "what\'s on my plate / my day".',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'read_my_context',
      'description':
          'Read the user\'s real on-device context — today\'s calendar events '
              'and current location (consent-gated, asked at point of use). Use '
              'when answering needs their actual day or whereabouts, e.g. '
              '"what\'s on my calendar?", "am I free at 3?", "should I leave '
              'now?".',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'mission_briefing',
      'description':
          'Get the user\'s cross-device mission briefing for an objective.',
      'parameters': {
        'type': 'object',
        'properties': {
          'objective': {'type': 'string'}
        },
        'required': ['objective'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'agent_plan',
      'description':
          'Build a concrete, step-by-step cross-device action plan for a goal, '
              'including any policy/safety warnings. Use when the user asks '
              '"how do I…", "make me a plan to…", or wants ALTER to map out the '
              'steps to achieve something.',
      'parameters': {
        'type': 'object',
        'properties': {
          'goal': {'type': 'string', 'description': 'The goal to plan for.'}
        },
        'required': ['goal'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'reputation_score',
      'description':
          'Get the user\'s reputation / track-record standing: a trust score, '
              'strengths, risks, and recommendations from their logged '
              'follow-through. Use for "what\'s my reputation", "how am I '
              'doing", "what\'s my track record".',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'capture_proof',
      'description':
          'Record a real achievement or completed milestone as PROOF — it '
              'writes to the user\'s twin memory, updates their reputation, and '
              'nudges their Future Twin. Use when the user reports they '
              'accomplished / shipped / won something. Provide a short title '
              'and a one-line summary of what they did.',
      'parameters': {
        'type': 'object',
        'properties': {
          'objective': {
            'type': 'string',
            'description': 'What the user set out to do / the achievement headline.'
          },
          'title': {
            'type': 'string',
            'description': 'Short title for the evidence (e.g. "1st place").'
          },
          'summary': {
            'type': 'string',
            'description': 'One-line description of what they accomplished.'
          },
        },
        'required': ['objective', 'summary'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'connect_contacts',
      'description':
          'Seed the user\'s ALTER social graph from their phone contacts (one '
              'time, consent-gated) so warm-intro discovery can work. Use when '
              'the user says "connect my contacts", "build my network", or asks '
              'for an intro and has no network yet.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'remember_person',
      'description':
          'Add a richly-described person to the user\'s network for warm-intro '
              'discovery. Use when the user tells you about someone they know '
              '("I know Priya, a senior ML recruiter at Google"). Extract the '
              'structured fields from their description — especially role, '
              'organization, and skills, which power discovery.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'The person\'s name.'},
          'role': {
            'type': 'string',
            'description':
                'One of: Recruiter, Professor, Founder, Investor, Student.'
          },
          'organization': {
            'type': 'string',
            'description': 'Company / school they\'re at.'
          },
          'headline': {
            'type': 'string',
            'description': 'Their title or a one-line description.'
          },
          'skills': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Skills / domains they work in.'
          },
          'interests': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Their interests, if mentioned.'
          },
        },
        'required': ['name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'find_intro',
      'description':
          'Find warm intro paths through the user\'s network to recruiters or '
              'mentors matching what they\'re looking for. Use for "who can '
              'introduce me to…", "find me a recruiter/mentor for…", "warm '
              'intro to…". Requires the network to be seeded (connect_contacts).',
      'parameters': {
        'type': 'object',
        'properties': {
          'looking_for': {
            'type': 'string',
            'description':
                'What/who they want, e.g. "ML recruiters in fintech" or "a '
                    'product design mentor".'
          },
          'kind': {
            'type': 'string',
            'enum': ['recruiter', 'mentor'],
            'description': 'Whether they want a recruiter or a mentor.'
          },
        },
        'required': ['looking_for'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'decision_dna',
      'description':
          'Read what ALTER has learned about how the user decides — their '
              'follow-through trust score and decision patterns.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'log_outcome',
      'description':
          'Record how something turned out, so ALTER learns the user\'s '
              'patterns over time (feeds the twin).',
      'parameters': {
        'type': 'object',
        'properties': {
          'what': {'type': 'string', 'description': 'What the decision/action was.'},
          'result': {
            'type': 'string',
            'description': 'How it went (worked, failed, regretted, verified safe…).'
          },
        },
        'required': ['what', 'result'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'record_feedback',
      'description':
          'Log the user\'s explicit feedback on a decision/suggestion so ALTER '
              'learns their preferences over time (stored locally + as memory). '
              'Use when they accept/reject/postpone/complete/regret something or '
              'rate it, or say it worked/failed.',
      'parameters': {
        'type': 'object',
        'properties': {
          'decision': {
            'type': 'string',
            'description': 'What decision or suggestion this is about.'
          },
          'kind': {
            'type': 'string',
            'enum': [
              'accepted',
              'rejected',
              'postponed',
              'completed',
              'regretted'
            ],
          },
          'outcome': {
            'type': 'string',
            'enum': ['positive', 'negative', 'neutral', 'unknown'],
          },
          'rating': {
            'type': 'integer',
            'description': '1–5 satisfaction, optional.'
          },
          'note': {
            'type': 'string',
            'description': 'Detail or follow-through evidence, optional.'
          },
        },
        'required': ['decision', 'kind'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'translate_text',
      'description':
          'Translate text into an Indian language via Sarvam (hi-IN, kn-IN, '
              'ta-IN, te-IN, ml-IN, mr-IN, gu-IN, pa-IN, bn-IN, en-IN).',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
          'target_language_code': {'type': 'string'},
        },
        'required': ['text', 'target_language_code'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'recall_memory',
      'description':
          'Search the user\'s on-device twin memory for what ALTER knows about '
              'a person, topic, or past event.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'}
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'trust_source',
      'description':
          'Mark a sender, domain, or app as trusted so LifeShield stops '
              'over-warning about it.',
      'parameters': {
        'type': 'object',
        'properties': {
          'value': {'type': 'string', 'description': 'The contact, domain, or app.'},
          'type': {
            'type': 'string',
            'enum': ['domain', 'contact', 'app']
          },
        },
        'required': ['value'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'safety_check',
      'description':
          'Check whether a message, link, QR/payment, or install prompt is safe '
          'to act on. Use whenever the user shares something suspicious or asks '
          '"is this safe / a scam".',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'The content to check.'},
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'plan_day',
      'description':
          'Model the user\'s day into Default / Risk / Optimized timelines and '
          'return pressure points and the single next best move.',
      'parameters': {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description':
                'The user\'s plans, deadlines, commute, meetings today.',
          },
        },
        'required': ['context'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'weigh_decision',
      'description':
          'Simulate a bigger life/work decision into Safe / Smart / Bold paths '
          'with a regret-minimizing recommendation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'decision': {
            'type': 'string',
            'description': 'The decision to weigh.',
          },
        },
        'required': ['decision'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'ask_council',
      'description':
          'Convene five inner voices (Practical, Risk, Future, Skeptic, Action) '
          'for an important decision; returns consensus + recommendation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'question': {'type': 'string'},
        },
        'required': ['question'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'find_contact',
      'description':
          'Look up a person in the user\'s contacts by name to get their phone '
          'number. Use this BEFORE calling or messaging someone by name '
          '(e.g. "call mom").',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
        'required': ['name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'call_number',
      'description': 'Open the phone dialer for a number (user taps to call).',
      'parameters': {
        'type': 'object',
        'properties': {
          'number': {'type': 'string'},
        },
        'required': ['number'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'send_message',
      'description':
          'Open WhatsApp or SMS with a prefilled message (user presses send).',
      'parameters': {
        'type': 'object',
        'properties': {
          'app': {
            'type': 'string',
            'enum': ['whatsapp', 'sms'],
          },
          'number': {'type': 'string'},
          'text': {'type': 'string'},
        },
        'required': ['app', 'number', 'text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'open_url',
      'description': 'Open a website or app link in the browser.',
      'parameters': {
        'type': 'object',
        'properties': {
          'url': {'type': 'string'},
        },
        'required': ['url'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'web_search',
      'description': 'Search the web for something.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'add_calendar_event',
      'description':
          'Open the calendar with an event prefilled (user saves it).',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'details': {'type': 'string'},
          'start_iso': {
            'type': 'string',
            'description': 'ISO-8601 start time if known.',
          },
        },
        'required': ['title'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'open_app',
      'description':
          'Open an installed Android app by common name or package name.',
      'parameters': {
        'type': 'object',
        'properties': {
          'app_name': {
            'type': 'string',
            'description': 'Common app name, e.g. WhatsApp, Chrome, Gmail.',
          },
          'package_name': {
            'type': 'string',
            'description': 'Android package name if known.',
          },
        },
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'open_settings',
      'description':
          'Open Android settings: accessibility, wifi, bluetooth, notifications, apps, battery, privacy, or general.',
      'parameters': {
        'type': 'object',
        'properties': {
          'screen': {'type': 'string'},
        },
        'required': ['screen'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'read_screen',
      'description':
          'Read visible on-screen text through the user-enabled Android Accessibility service.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'click_text',
      'description':
          'Click a visible UI element by text through Accessibility. Do not use for Send, Pay, Confirm, Install, Approve, or other high-impact final actions.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'type_text',
      'description':
          'Type text into the currently focused editable field through Accessibility.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'press_phone_button',
      'description':
          'Perform a global Android Accessibility action: back, home, recents, notifications, or quick_settings.',
      'parameters': {
        'type': 'object',
        'properties': {
          'button': {
            'type': 'string',
            'enum': [
              'back',
              'home',
              'recents',
              'notifications',
              'quick_settings',
            ],
          },
        },
        'required': ['button'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'scroll_screen',
      'description':
          'Scroll the current visible screen forward/down or backward/up through Accessibility.',
      'parameters': {
        'type': 'object',
        'properties': {
          'direction': {
            'type': 'string',
            'enum': ['forward', 'backward', 'up', 'down'],
          },
        },
        'required': ['direction'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'queue_openclaw_action',
      'description':
          'Queue a phone action in OpenClaw for explicit user review and confirmation. Use for send/pay/install/approve/delete or any action that commits something.',
      'parameters': {
        'type': 'object',
        'properties': {
          'action_type': {'type': 'string'},
          'title': {'type': 'string'},
          'detail': {'type': 'string'},
          'irreversible': {'type': 'boolean'},
        },
        'required': ['action_type', 'title'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'notification_reply',
      'description':
          'Reply to the latest Android notification only when Android exposes a quick-reply action. Use only after explicit user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
          'package_name': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'run_phone_agent_loop',
      'description':
          'Run the observe-plan-act phone loop: observe screen, plan, execute safe step, re-observe, and audit.',
      'parameters': {
        'type': 'object',
        'properties': {
          'goal': {'type': 'string'},
        },
        'required': ['goal'],
      },
    },
  },
];

/// Short human label for a tool, shown as a chip while it runs.
String agentToolLabel(String name) => switch (name) {
      'find_opportunities' => 'Scanning opportunities…',
      'read_life_feed' => 'Reading your day…',
      'read_my_context' => 'Checking your day…',
      'mission_briefing' => 'Building briefing…',
      'agent_plan' => 'Drafting a plan…',
      'reputation_score' => 'Checking your standing…',
      'capture_proof' => 'Capturing proof…',
      'connect_contacts' => 'Building your network…',
      'remember_person' => 'Saving to your network…',
      'find_intro' => 'Finding warm intros…',
      'decision_dna' => 'Reading your Decision DNA…',
      'log_outcome' => 'Recording outcome…',
      'record_feedback' => 'Logging feedback…',
      'translate_text' => 'Translating…',
      'recall_memory' => 'Recalling memory…',
      'trust_source' => 'Trusting source…',
  'find_contact' => 'Looking up contact…',
  'safety_check' => 'Running LifeShield…',
  'plan_day' => 'Modeling your day…',
  'weigh_decision' => 'Simulating futures…',
  'ask_council' => 'Convening the council…',
  'call_number' => 'Opening dialer…',
  'send_message' => 'Opening message…',
  'open_url' => 'Opening link…',
  'web_search' => 'Searching the web…',
  'notification_reply' => 'Replying to notification...',
  'run_phone_agent_loop' => 'Running phone agent loop...',
  'add_calendar_event' => 'Opening calendar…',
  'open_app' => 'Opening app...',
  'open_settings' => 'Opening settings...',
  'read_screen' => 'Reading visible screen...',
  'click_text' => 'Clicking visible item...',
  'type_text' => 'Typing text...',
  'press_phone_button' => 'Pressing phone control...',
  'scroll_screen' => 'Scrolling screen...',
  'queue_openclaw_action' => 'Queuing OpenClaw action...',
  _ => 'Working…',
};

/// Executes a tool call and returns a concise text result for the model.
Future<String> executeAgentTool(
  Ref ref,
  String name,
  Map<String, dynamic> args,
) async {
  const device = DeviceActions();
  final phone = ref.read(phoneControlControllerProvider.notifier);
  String s(String k) => (args[k] ?? '').toString();

  switch (name) {
    case 'find_opportunities':
      {
        // Hold a subscription so this autoDispose provider can't self-dispose
        // during its own network await (which throws "Cannot use the Ref ...
        // after it has been disposed" and crashes the tool turn).
        final sub = ref.listen(opportunitiesProvider, (_, _) {});
        try {
          final opps = await ref.read(opportunitiesProvider.future);
          if (opps.isEmpty) {
            return 'No matched opportunities yet — the user needs skills/goals '
                'in their profile, or the radar backend is unreachable.';
          }
          return opps
              .take(5)
              .map((o) =>
                  '${o.title} (${o.category}, ${(o.score * 100).round()}% match, '
                  '${o.source}) — ${o.window}')
              .join(' | ');
        } finally {
          sub.close();
        }
      }
    case 'read_life_feed':
      {
        final sub = ref.listen(lifeFeedProvider, (_, _) {});
        Map<String, dynamic>? feed;
        try {
          feed = await ref.read(lifeFeedProvider.future);
        } finally {
          sub.close();
        }
        if (feed == null) {
          return 'Life feed unavailable — sign in and a reachable backend are needed.';
        }
        final tasks = feed['tasks'] is List
            ? (feed['tasks'] as List)
            : const <dynamic>[];
        final taskLine = tasks
            .whereType<Map<dynamic, dynamic>>()
            .take(5)
            .map((t) =>
                '${t['title']}${t['done'] == true ? ' (done)' : ''}')
            .join('; ');
        return '${feed['greeting'] ?? ''} ${feed['date_summary'] ?? ''} '
            'Focus: ${feed['focus_title'] ?? '—'}. Today: $taskLine';
      }
    case 'read_my_context':
      return ref.read(onDeviceContextProvider).snapshot();
    case 'mission_briefing':
      {
        final cfg = await ref.read(backendConfigProvider.future);
        if (!cfg.hasGateway) return 'No backend gateway configured.';
        final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
        try {
          final body = await client.postJson('/v1/mission/briefing', {
            'objective': s('objective'),
            'device_context': 'flutter',
          });
          return (body?['command_summary'] ?? 'Briefing ready.').toString();
        } finally {
          client.close();
        }
      }
    case 'agent_plan':
      {
        final cfg = await ref.read(backendConfigProvider.future);
        if (!cfg.hasGateway) return 'No backend gateway configured.';
        final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
        try {
          // Hybrid retrieval: send the phone's own relevant local memory up as
          // labeled, privacy-filtered client_context. The gateway merges it
          // with backend context (older gateways simply ignore the field).
          const filter = ContextPrivacyFilter(maxChars: 400);
          final mems = await ref
              .read(persistentIntelligenceStoreProvider.notifier)
              .searchMemory(s('goal'));
          final clientContext = mems
              .take(6)
              .map((m) => <String, dynamic>{
                    'source': 'local',
                    'text': filter.filter('${m.title}: ${m.summary}'),
                  })
              .where((c) => (c['text'] as String).trim().isNotEmpty)
              .toList();
          final body = await client.postJson('/v1/agent/plan', {
            'goal': s('goal'),
            'autonomy_level': 'confirm_before_act',
            if (clientContext.isNotEmpty) 'client_context': clientContext,
          });
          if (body == null) return 'Could not build a plan right now.';
          final steps = (body['steps'] is List ? body['steps'] as List : const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .take(6)
              .toList();
          if (steps.isEmpty) {
            return 'No actionable steps were produced for that goal.';
          }
          final lines = <String>[];
          for (var i = 0; i < steps.length; i++) {
            lines.add('${i + 1}. ${steps[i]['title']}');
          }
          final warns = (body['policy_warnings'] is List
                  ? body['policy_warnings'] as List
                  : const <dynamic>[])
              .map((w) => w.toString())
              .where((w) => w.isNotEmpty)
              .toList();
          final tail = warns.isEmpty
              ? (body['ready_to_execute'] == true
                  ? ' Ready to run on your confirmation.'
                  : '')
              : ' Heads up: ${warns.join('; ')}.';
          return 'Plan for "${s('goal')}": ${lines.join('  ')}.$tail';
        } finally {
          client.close();
        }
      }
    case 'reputation_score':
      {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) {
          return 'Sign in first — reputation is tied to the user\'s account.';
        }
        final cfg = await ref.read(backendConfigProvider.future);
        if (!cfg.hasGateway) return 'No backend gateway configured.';
        final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
        try {
          final body = await client.getJson('/v1/reputation/users/$uid/score');
          if (body == null) return 'Reputation unavailable right now.';
          final strengths = (body['strengths'] is List
                  ? body['strengths'] as List
                  : const <dynamic>[])
              .map((e) => e.toString())
              .take(2)
              .join('; ');
          final recs = (body['recommendations'] is List
                  ? body['recommendations'] as List
                  : const <dynamic>[])
              .map((e) => e.toString())
              .take(2)
              .join('; ');
          return 'Reputation ${body['score']}/1000 (${body['trust_level']}). '
              'Strengths: ${strengths.isEmpty ? '—' : strengths}. '
              'To improve: ${recs.isEmpty ? '—' : recs}.';
        } finally {
          client.close();
        }
      }
    case 'capture_proof':
      {
        final cfg = await ref.read(backendConfigProvider.future);
        if (!cfg.hasGateway) return 'No backend gateway configured.';
        final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
        try {
          final title = s('title').isNotEmpty ? s('title') : s('objective');
          final body = await client.postJson('/v1/proof/capture', {
            'objective': s('objective'),
            'source_surface': 'voice',
            'evidence': [
              <String, dynamic>{
                'evidence_type': 'artifact',
                'title': title,
                'summary': s('summary'),
                'source': 'alter_voice',
              }
            ],
          });
          if (body == null) return 'Could not capture that proof right now.';
          final next = (body['next_actions'] is List
                  ? body['next_actions'] as List
                  : const <dynamic>[])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .take(2)
              .join('; ');
          return 'Captured as proof — it\'s now in the user\'s twin memory and '
              'reputation ledger.${next.isEmpty ? '' : ' Next: $next.'}';
        } finally {
          client.close();
        }
      }
    case 'connect_contacts':
      {
        final count =
            await ref.read(socialGraphServiceProvider).importContacts();
        switch (count) {
          case -1:
            return 'Contacts permission was denied, so I couldn\'t build the '
                'network. Grant Contacts access and try again.';
          case -2:
            return 'No backend gateway configured — the social graph lives on '
                'the backend.';
          case -3:
            return 'Couldn\'t anchor your profile in the graph. Sign in and '
                'fill your profile, then retry.';
          case 0:
            return 'No usable contacts found to import.';
          default:
            return 'Added you plus $count contacts to your network. Now ask me '
                'to find a warm intro to a recruiter or mentor.';
        }
      }
    case 'remember_person':
      {
        List<String> list(String k) => (args[k] is List)
            ? (args[k] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : const <String>[];
        return ref.read(socialGraphServiceProvider).rememberPerson(
              name: s('name'),
              role: s('role'),
              organization: s('organization'),
              headline: s('headline'),
              skills: list('skills'),
              interests: list('interests'),
            );
      }
    case 'find_intro':
      {
        final lookingFor = s('looking_for');
        var kind = s('kind').toLowerCase();
        if (kind != 'recruiter' && kind != 'mentor') {
          kind = lookingFor.toLowerCase().contains('mentor')
              ? 'mentor'
              : 'recruiter';
        }
        final terms = lookingFor
            .split(RegExp(r'[\s,]+'))
            .where((w) => w.length >= 3)
            .toList();
        if (terms.isEmpty && lookingFor.isNotEmpty) terms.add(lookingFor);
        return ref
            .read(socialGraphServiceProvider)
            .discover(kind: kind, terms: terms);
      }
    case 'decision_dna':
      {
        final dna = await ref.read(decisionDnaProvider.future);
        final pats = dna.patterns.take(4).map((p) => p.pattern).join('; ');
        return 'Follow-through ${(dna.trustScore * 100).round()}%. '
            'Patterns: ${pats.isEmpty ? 'still learning' : pats}.';
      }
    case 'log_outcome':
      await ref.read(persistentIntelligenceStoreProvider.notifier).addMemory(
            source: 'outcome',
            title: s('what'),
            summary: 'Outcome: ${s('result')}',
          );
      return 'Logged. ALTER will factor this into your Decision DNA.';
    case 'record_feedback':
      {
        final kind = feedbackKindFromString(s('kind'));
        final event = FeedbackEvent(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          decision: s('decision'),
          kind: kind,
          outcome: valenceFromString(s('outcome')),
          rating: int.tryParse(s('rating')),
          note: s('note'),
          at: DateTime.now(),
        );
        await ref.read(feedbackLogProvider.notifier).record(event);
        await ref.read(persistentIntelligenceStoreProvider.notifier).addMemory(
              source: 'feedback',
              title: '${kind.name}: ${s('decision')}',
              summary: s('note').isEmpty
                  ? 'Feedback recorded (${kind.name}).'
                  : s('note'),
            );
        return 'Logged your feedback (${kind.name}) on "${s('decision')}".';
      }
    case 'translate_text':
      {
        final cfg = await ref.read(backendConfigProvider.future);
        if (!cfg.hasGateway) return 'No backend gateway configured.';
        final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
        try {
          final body = await client.postJson('/v1/multilingual/translate', {
            'text': s('text'),
            'target_language_code': s('target_language_code'),
          });
          return (body?['translated_text'] ??
                  body?['output'] ??
                  body?['text'] ??
                  'Translation unavailable.')
              .toString();
        } finally {
          client.close();
        }
      }
    case 'recall_memory':
      {
        final hits = await ref
            .read(persistentIntelligenceStoreProvider.notifier)
            .searchMemory(s('query'));
        if (hits.isEmpty) {
          return 'Nothing in memory about "${s('query')}" yet.';
        }
        return hits.take(6).map((m) => '${m.title}: ${m.summary}').join('; ');
      }
    case 'trust_source':
      {
        final type = s('type').isNotEmpty
            ? s('type')
            : (s('value').contains('.') ? 'domain' : 'contact');
        await ref.read(memoryProvider.notifier).addTrusted(type, s('value'));
        return 'Trusted ${s('value')}. LifeShield will stop over-warning about it.';
      }
    case 'safety_check':
      final ls = ref.read(lifeShieldControllerProvider.notifier);
      ls.setSource(MomentSource.shareSheet);
      ls.setInput(s('text'));
      await ls.capture();
      final a = ref.read(lifeShieldControllerProvider).analysis;
      if (a == null) return 'No analysis available.';
      return 'Verdict: ${a.verdict.label}. ${a.headline}. ${a.whyItMatters} '
          '${a.redFlags.isEmpty ? '' : 'Red flags: ${a.redFlags.join('; ')}.'}';

    case 'plan_day':
      final d = ref.read(dayTwinControllerProvider.notifier);
      d.setInput(s('context'));
      await d.simulate();
      final r = ref.read(dayTwinControllerProvider).result;
      if (r == null) return 'No plan available.';
      return '${r.headline}. Next best move: ${r.nextBestMove}. '
          'Pressure points: ${r.pressurePoints.join('; ')}.';

    case 'weigh_decision':
      final f = ref.read(futureTwinControllerProvider.notifier);
      f.setInput(s('decision'));
      await f.simulate();
      final r = ref.read(futureTwinControllerProvider).result;
      if (r == null) return 'No simulation available.';
      return '${r.headline}. ${r.summary} Recommended path: ${r.recommended}. '
          '${r.regretMinimizer}';

    case 'ask_council':
      final c = ref.read(decisionCouncilProvider.notifier);
      c.setTopic(s('question'));
      await c.convene();
      final r = ref.read(decisionCouncilProvider).result;
      if (r == null) return 'No council result.';
      return 'Consensus: ${r.consensus} Recommendation: ${r.recommendation} '
          'Dissent: ${r.dissent}';

    case 'find_contact':
      return device.findContact(s('name'));
    case 'call_number':
      return device.callNumber(s('number'));
    case 'send_message':
      return device.sendMessage(
        app: s('app'),
        number: s('number'),
        text: s('text'),
      );
    case 'open_url':
      return device.openUrl(s('url'));
    case 'web_search':
      return phone.browserSearch(s('query'));
    case 'notification_reply':
      return ref
          .read(notificationMonitorProvider.notifier)
          .replyToLatest(text: s('text'), packageName: s('package_name'));
    case 'run_phone_agent_loop':
      await ref.read(agentExecutionRuntimeProvider.notifier).runGoal(s('goal'));
      final runtime = ref.read(agentExecutionRuntimeProvider);
      return 'Phone loop completed ${runtime.completedSteps}/${runtime.plan.length} steps. Latest audit: ${runtime.audit.isEmpty ? 'none' : runtime.audit.first.summary}';
    case 'add_calendar_event':
      return device.addCalendarEvent(
        title: s('title'),
        details: s('details'),
        startIso: s('start_iso'),
      );
    case 'open_app':
      return phone.openApp(
        appName: s('app_name'),
        packageName: s('package_name'),
      );
    case 'open_settings':
      return phone.openSettings(s('screen'));
    case 'read_screen':
      final snapshot = await phone.readScreen();
      if (!snapshot.ok) return snapshot.message;
      final structured = ref
          .read(phoneControlControllerProvider)
          .lastStructuredScreen;
      return structured?.toAgentSummary() ?? snapshot.message;
    case 'click_text':
      final target = s('text');
      if (_isHighImpactClick(target)) {
        return 'I can prepare this, but I will not click "$target" directly. Use OpenClaw confirmation for final send/pay/install/approve actions.';
      }
      return phone.clickText(target);
    case 'type_text':
      return phone.typeText(s('text'));
    case 'press_phone_button':
      return phone.press(s('button'));
    case 'scroll_screen':
      return phone.scroll(s('direction'));
    case 'queue_openclaw_action':
      return ref
          .read(openClawQueueProvider.notifier)
          .enqueueStructured(
            type: s('action_type'),
            title: s('title'),
            detail: s('detail'),
            irreversible: args['irreversible'] == true,
          );
    default:
      return 'Unknown tool: $name';
  }
}

bool _isHighImpactClick(String text) {
  return RegExp(
    r'\b(send|pay|confirm|approve|install|buy|purchase|transfer|delete|allow|grant)\b',
    caseSensitive: false,
  ).hasMatch(text);
}

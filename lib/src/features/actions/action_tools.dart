import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/alter_gateway_config.dart';
import '../auth/application/auth_provider.dart';
import '../../data/gateway/alter_gateway_providers.dart';
import '../../data/gateway/gateway_intelligence_bridge.dart';
import '../../data/gateway/gateway_profile_context.dart';
import '../mission/application/mission_control_provider.dart'
    hide futureTwinControllerProvider;
import '../mission/data/mission_control_api_client.dart';
import '../profile/application/profile_provider.dart';
import '../contextos/application/daytwin_controller.dart';
import '../contextos/application/decision_council_controller.dart';
import '../contextos/application/futuretwin_controller.dart';
import '../contextos/application/lifeshield_controller.dart';
import '../contextos/application/openclaw_adapter.dart';
import '../contextos/domain/contextos_models.dart';
import '../device_control/application/phone_control_controller.dart';
import '../device_control/domain/phone_action_policy.dart';
import '../agent/data/device_actions.dart';
import 'action_autonomy_policy.dart';
import 'action_composer.dart';
import 'action_preferences.dart';

/// OpenAI tool schemas shared across Agent, Voice, and ContextOS.
final kActionTools = <Map<String, dynamic>>[
  _fn(
    'safety_check',
    'Check whether a message, link, QR/payment, or install prompt is safe.',
    {'text': _str('The content to check.')},
    ['text'],
  ),
  _fn(
    'plan_day',
    'Model the user\'s day into Default / Risk / Optimized timelines.',
    {'context': _str('Plans, deadlines, commute, meetings today.')},
    ['context'],
  ),
  _fn(
    'weigh_decision',
    'Simulate a life/work decision into Safe / Smart / Bold paths.',
    {'decision': _str('The decision to weigh.')},
    ['decision'],
  ),
  _fn(
    'ask_council',
    'Convene five inner voices for an important decision.',
    {'question': _str('The question.')},
    ['question'],
  ),
  _fn(
    'find_contact',
    'Look up a contact by name BEFORE calling or messaging them.',
    {'name': _str('Contact name.')},
    ['name'],
  ),
  _fn(
    'call_number',
    'Open the phone dialer for a number.',
    {'number': _str('Phone number.')},
    ['number'],
  ),
  _fn(
    'research_web',
    'Search the web and return snippets to answer a factual question. Prefer over web_search.',
    {'query': _str('Search query.')},
    ['query'],
  ),
  _fn(
    'fetch_page',
    'Fetch readable text from a URL for answering questions.',
    {'url': _str('Full URL.')},
    ['url'],
  ),
  _fn(
    'search_marketplace',
    'Search shopping listings on a marketplace platform.',
    {
      'query': _str('Product or listing search.'),
      'platform': {
        'type': 'string',
        'enum': ['amazon', 'flipkart', 'facebook_marketplace', 'olx'],
      },
    },
    ['query', 'platform'],
  ),
  _fn(
    'search_opportunities',
    'Find internships, grants, hackathons, and fellowships.',
    {'query': _str('Opportunity search query.')},
    ['query'],
  ),
  _fn(
    'compose_message',
    'Draft and send (or queue) a WhatsApp or SMS message.',
    {
      'channel': {'type': 'string', 'enum': ['whatsapp', 'sms']},
      'recipient': _str('Contact name or phone number.'),
      'intent': _str('What the message should convey.'),
      'tone': _str('friendly, formal, or casual.'),
      'body': _str('Optional draft body; ALTER will polish if empty.'),
      'number': _str('Phone number if already known.'),
    },
    ['channel', 'recipient', 'intent'],
  ),
  _fn(
    'compose_email',
    'Draft and send (or queue) an email.',
    {
      'to': _str('Recipient email or name.'),
      'subject': _str('Email subject.'),
      'intent': _str('What the email should convey.'),
      'tone': _str('professional or friendly.'),
      'body': _str('Optional draft body.'),
    },
    ['to', 'intent'],
  ),
  _fn(
    'schedule_event',
    'Create a calendar event.',
    {
      'title': _str('Event title.'),
      'start_iso': _str('ISO-8601 start time.'),
      'end_iso': _str('ISO-8601 end time.'),
      'location': _str('Location.'),
      'notes': _str('Notes or description.'),
    },
    ['title', 'start_iso'],
  ),
  _fn(
    'read_calendar',
    'Read upcoming calendar events for the next few days.',
    {'days': {'type': 'integer', 'description': 'Days ahead to read (default 3).'}},
    [],
  ),
  _fn(
    'send_message',
    'Open WhatsApp or SMS with prefilled text (legacy; prefer compose_message).',
    {
      'app': {'type': 'string', 'enum': ['whatsapp', 'sms']},
      'number': _str('Phone number.'),
      'text': _str('Message body.'),
    },
    ['app', 'number', 'text'],
  ),
  _fn('open_url', 'Open a link in the browser.', {'url': _str('URL.')}, ['url']),
  _fn(
    'web_search',
    'Open Google search in browser when user wants to browse manually.',
    {'query': _str('Search query.')},
    ['query'],
  ),
  _fn(
    'add_calendar_event',
    'Open Google Calendar with prefilled event (legacy; prefer schedule_event).',
    {
      'title': _str('Title.'),
      'details': _str('Details.'),
      'start_iso': _str('ISO-8601 start.'),
    },
    ['title'],
  ),
  _fn(
    'open_app',
    'Open an installed Android app.',
    {
      'app_name': _str('Common name, e.g. WhatsApp, Gmail.'),
      'package_name': _str('Android package if known.'),
    },
    [],
  ),
  _fn(
    'open_settings',
    'Open Android settings screen.',
    {'screen': _str('accessibility, wifi, bluetooth, etc.')},
    ['screen'],
  ),
  _fn('read_screen', 'Read visible on-screen text via Accessibility.', {}, []),
  _fn(
    'click_text',
    'Click visible UI text via Accessibility. Not for Send/Pay/Confirm.',
    {'text': _str('Visible label to click.')},
    ['text'],
  ),
  _fn(
    'type_text',
    'Type into the focused field via Accessibility.',
    {'text': _str('Text to type.')},
    ['text'],
  ),
  _fn(
    'press_phone_button',
    'Global Android action: back, home, recents, notifications, quick_settings.',
    {
      'button': {
        'type': 'string',
        'enum': ['back', 'home', 'recents', 'notifications', 'quick_settings'],
      },
    },
    ['button'],
  ),
  _fn(
    'scroll_screen',
    'Scroll the visible screen.',
    {
      'direction': {
        'type': 'string',
        'enum': ['forward', 'backward', 'up', 'down'],
      },
    },
    ['direction'],
  ),
  _fn(
    'queue_openclaw_action',
    'Queue an action for user review in OpenClaw.',
    {
      'action_type': _str('Action type.'),
      'title': _str('Short title.'),
      'detail': _str('Details.'),
      'irreversible': {'type': 'boolean'},
    },
    ['action_type', 'title'],
  ),
];

Map<String, dynamic> _fn(
  String name,
  String description,
  Map<String, dynamic> properties,
  List<String> required,
) =>
    {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };

Map<String, dynamic> _str(String description) => {
      'type': 'string',
      'description': description,
    };

/// Back-compat alias.
final kAgentTools = kActionTools;

String actionToolLabel(String name) => agentToolLabel(name);

String agentToolLabel(String name) => switch (name) {
      'find_contact' => 'Looking up contact…',
      'safety_check' => 'Running LifeShield…',
      'plan_day' => 'Modeling your day…',
      'weigh_decision' => 'Simulating futures…',
      'ask_council' => 'Convening the council…',
      'call_number' => 'Opening dialer…',
      'compose_message' => 'Drafting message…',
      'compose_email' => 'Drafting email…',
      'schedule_event' => 'Scheduling event…',
      'read_calendar' => 'Reading calendar…',
      'research_web' => 'Researching…',
      'fetch_page' => 'Fetching page…',
      'search_marketplace' => 'Searching marketplace…',
      'search_opportunities' => 'Finding opportunities…',
      'send_message' => 'Opening message…',
      'open_url' => 'Opening link…',
      'web_search' => 'Searching the web…',
      'add_calendar_event' => 'Opening calendar…',
      'open_app' => 'Opening app…',
      'open_settings' => 'Opening settings…',
      'read_screen' => 'Reading screen…',
      'click_text' => 'Clicking item…',
      'type_text' => 'Typing…',
      'press_phone_button' => 'Phone control…',
      'scroll_screen' => 'Scrolling…',
      'queue_openclaw_action' => 'Queuing action…',
      _ => 'Working…',
    };

Future<String> executeActionTool(
  Ref ref,
  String name,
  Map<String, dynamic> args,
) =>
    executeAgentTool(ref, name, args);

Future<String> executeAgentTool(
  Ref ref,
  String name,
  Map<String, dynamic> args,
) async {
  const device = DeviceActions();
  final phone = ref.read(phoneControlControllerProvider.notifier);
  String s(String k) => (args[k] ?? '').toString();

  switch (name) {
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
      if (AlterGatewayConfig.isConfigured) {
        final userId = ref.read(localUserIdProvider);
        final plan = await ref.read(alterGatewayApiClientProvider).planAgent(
              goal: 'Plan my day: ${s('context')}',
              userId: userId,
              allowedTools: const ['calendar', 'reminders', 'focus_block'],
            );
        return formatAgentPlan(plan);
      }
      final d = ref.read(dayTwinControllerProvider.notifier);
      d.setInput(s('context'));
      await d.simulate();
      final r = ref.read(dayTwinControllerProvider).result;
      if (r == null) return 'No plan available.';
      return '${r.headline}. Next: ${r.nextBestMove}. '
          'Pressure: ${r.pressurePoints.join('; ')}.';

    case 'weigh_decision':
      if (AlterGatewayConfig.isConfigured) {
        final profile = ref.read(userProfileProvider).asData?.value;
        final report = await ref.read(missionControlApiClientProvider).decide(
              question: s('decision'),
              userProfile: GatewayProfileContext.userProfile(profile),
              skills: GatewayProfileContext.skills(profile),
              goals: GatewayProfileContext.goals(profile),
              interests: GatewayProfileContext.interests(profile),
            );
        final mapped =
            futureTwinFromDecision(report, question: s('decision'));
        return '${mapped.headline}. ${mapped.summary} Recommended: ${mapped.recommended}.';
      }
      final f = ref.read(futureTwinControllerProvider.notifier);
      f.setInput(s('decision'));
      await f.simulate();
      final fr = ref.read(futureTwinControllerProvider).result;
      if (fr == null) return 'No simulation available.';
      return '${fr.headline}. Recommended: ${fr.recommended}.';

    case 'ask_council':
      final c = ref.read(decisionCouncilProvider.notifier);
      c.setTopic(s('question'));
      await c.convene();
      final cr = ref.read(decisionCouncilProvider).result;
      if (cr == null) return 'No council result.';
      return 'Consensus: ${cr.consensus} Recommendation: ${cr.recommendation}';

    case 'find_contact':
      return device.findContact(s('name'));

    case 'call_number':
      return device.callNumber(s('number'));

    case 'research_web':
      return _researchWeb(ref, s('query'));

    case 'fetch_page':
      return _fetchPage(ref, s('url'));

    case 'search_marketplace':
      return _searchMarketplace(ref, s('query'), s('platform'));

    case 'search_opportunities':
      return _searchOpportunities(ref, s('query'));

    case 'compose_message':
      return _composeMessage(ref, args);

    case 'compose_email':
      return _composeEmail(ref, args);

    case 'schedule_event':
      return _scheduleEvent(ref, args);

    case 'read_calendar':
      final days = int.tryParse(s('days')) ?? 3;
      return device.readUpcomingEvents(daysAhead: days);

    case 'send_message':
      return _legacySend(ref, device, s('app'), s('number'), s('text'));

    case 'open_url':
      return device.openUrl(s('url'));

    case 'web_search':
      return device.webSearch(s('query'));

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
      final structured =
          ref.read(phoneControlControllerProvider).lastStructuredScreen;
      return structured?.toAgentSummary() ?? snapshot.message;

    case 'click_text':
      final target = s('text');
      if (_isHighImpactClick(target)) {
        return 'Cannot click "$target" directly. Use compose_* or OpenClaw.';
      }
      return phone.clickText(target);

    case 'type_text':
      return phone.typeText(s('text'));

    case 'press_phone_button':
      return phone.press(s('button'));

    case 'scroll_screen':
      return phone.scroll(s('direction'));

    case 'queue_openclaw_action':
      return ref.read(openClawQueueProvider.notifier).enqueueStructured(
            type: s('action_type'),
            title: s('title'),
            detail: s('detail'),
            irreversible: args['irreversible'] == true,
          );

    default:
      return 'Unknown tool: $name';
  }
}

Future<String> _researchWeb(Ref ref, String query) async {
  if (query.trim().isEmpty) return 'Query is empty.';
  if (AlterGatewayConfig.isConfigured) {
    try {
      final hits = await ref.read(alterGatewayApiClientProvider).researchWeb(
            query: query,
          );
      if (hits.isEmpty) {
        return 'No web results found for "$query".';
      }
      return hits
          .map((h) => '${h.title}: ${h.snippet} (${h.url})')
          .join('\n');
    } catch (e) {
      return 'Web research failed ($e). Try again when gateway is online.';
    }
  }
  const device = DeviceActions();
  await device.webSearch(query);
  return 'Gateway offline — opened browser search for "$query". '
      'Configure ALTER gateway for in-app research answers.';
}

Future<String> _fetchPage(Ref ref, String url) async {
  if (url.trim().isEmpty) return 'URL is empty.';
  if (!AlterGatewayConfig.isConfigured) {
    return 'Gateway required to fetch page content.';
  }
  try {
    final page = await ref.read(alterGatewayApiClientProvider).fetchPage(url: url);
    return '${page.title}\n${page.excerpt}';
  } catch (e) {
    return 'Could not fetch page: $e';
  }
}

Future<String> _searchMarketplace(
  Ref ref,
  String query,
  String platform,
) async {
  if (query.trim().isEmpty) return 'Query is empty.';
  if (!AlterGatewayConfig.isConfigured) {
    const device = DeviceActions();
    await device.webSearch('$platform $query');
    return 'Gateway offline — opened browser for $platform search.';
  }
  try {
    final listings = await ref
        .read(alterGatewayApiClientProvider)
        .searchMarketplace(query: query, platform: platform);
    if (listings.isEmpty) return 'No listings found on $platform for "$query".';
    return listings
        .map((l) => '${l.title} — ${l.price} (${l.url})')
        .join('\n');
  } catch (e) {
    return 'Marketplace search failed: $e';
  }
}

Future<String> _searchOpportunities(Ref ref, String query) async {
  if (query.trim().isEmpty) return 'Query is empty.';
  if (!AlterGatewayConfig.isConfigured) {
    return 'Configure ALTER gateway to search opportunities.';
  }
  try {
    final items = await ref
        .read(alterGatewayApiClientProvider)
        .searchOpportunities(query: query);
    if (items.isEmpty) return 'No opportunities found for "$query".';
    return items
        .map((o) => '${o.title} (${o.organization}) — ${o.url}')
        .join('\n');
  } catch (e) {
    return 'Opportunity search failed: $e';
  }
}

Future<String> _composeMessage(Ref ref, Map<String, dynamic> args) async {
  final channel = (args['channel'] ?? 'whatsapp').toString().toLowerCase();
  final recipient = (args['recipient'] ?? '').toString();
  final intent = (args['intent'] ?? '').toString();
  final tone = (args['tone'] ?? 'friendly').toString();
  var number = (args['number'] ?? '').toString();
  const device = DeviceActions();

  if (number.isEmpty && recipient.isNotEmpty && !RegExp(r'\d{6,}').hasMatch(recipient)) {
    final found = await device.findContact(recipient);
    number = _extractPhone(found) ?? '';
    if (number.isEmpty) return 'Could not find phone number for "$recipient".';
  } else if (number.isEmpty) {
    number = recipient.replaceAll(RegExp(r'[^\d+]'), '');
  }

  if (number.isEmpty) return 'Need a recipient phone number.';

  final profile = ref.read(userProfileProvider).asData?.value;
  final body = ActionComposer.polishMessage(
    intent: intent,
    body: (args['body'] ?? '').toString(),
    profile: profile,
    tone: tone,
    channel: channel,
  );

  final decision = await ref.read(actionAutonomyPolicyProvider).evaluateSend(
        channel: channel,
        recipientLabel: recipient,
        recipientValue: number,
      );

  if (decision.canAutoSend) {
    final ok = await ref
        .read(actionPreferencesProvider.notifier)
        .recordFullAutoSend();
    if (!ok) {
      return _queueMessage(ref, channel, recipient, number, body);
    }
    return _autoSendMessage(ref, channel, number, body);
  }

  return _queueMessage(ref, channel, recipient, number, body);
}

Future<String> _queueMessage(
  Ref ref,
  String channel,
  String recipient,
  String number,
  String body,
) async {
  return ref.read(openClawQueueProvider.notifier).enqueueCompose(
        kind: channel == 'sms' ? 'send_sms' : 'send_whatsapp',
        title: '${channel == 'sms' ? 'SMS' : 'WhatsApp'} to $recipient',
        channel: channel,
        recipient: recipient,
        number: number,
        body: body,
      );
}

Future<String> _autoSendMessage(
  Ref ref,
  String channel,
  String number,
  String body,
) async {
  final result = await ref.read(openClawQueueProvider.notifier).enqueueComposeAndExecute(
        kind: channel == 'sms' ? 'send_sms' : 'send_whatsapp',
        title: 'Auto-send ${channel == 'sms' ? 'SMS' : 'WhatsApp'}',
        channel: channel,
        recipient: number,
        number: number,
        body: body,
      );
  return 'Auto-sent. $result Message: ${body.length > 80 ? '${body.substring(0, 77)}...' : body}';
}

Future<String> _composeEmail(Ref ref, Map<String, dynamic> args) async {
  final to = (args['to'] ?? '').toString();
  final intent = (args['intent'] ?? '').toString();
  final tone = (args['tone'] ?? 'professional').toString();
  final profile = ref.read(userProfileProvider).asData?.value;
  final polished = ActionComposer.polishEmail(
    intent: intent,
    subject: (args['subject'] ?? '').toString(),
    body: (args['body'] ?? '').toString(),
    profile: profile,
    tone: tone,
  );

  final decision = await ref.read(actionAutonomyPolicyProvider).evaluateSend(
        channel: 'email',
        recipientLabel: to,
        recipientValue: to.contains('@') ? to : null,
      );

  if (decision.canAutoSend) {
    final ok = await ref
        .read(actionPreferencesProvider.notifier)
        .recordFullAutoSend();
    if (ok) {
      const device = DeviceActions();
      await device.composeEmail(
        to: to.contains('@') ? to : '',
        subject: polished.subject,
        body: polished.body,
      );
      final phone = ref.read(phoneControlControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return phone.clickText(
        'Send',
        surface: PhoneActionSurface.openClawConfirmed,
      );
    }
  }

  return ref.read(openClawQueueProvider.notifier).enqueueCompose(
        kind: 'send_email',
        title: 'Email to $to',
        channel: 'email',
        recipient: to,
        number: '',
        body: polished.body,
        subject: polished.subject,
      );
}

Future<String> _scheduleEvent(Ref ref, Map<String, dynamic> args) async {
  const device = DeviceActions();
  final title = (args['title'] ?? '').toString();
  final startIso = (args['start_iso'] ?? '').toString();
  final endIso = (args['end_iso'] ?? '').toString();
  final location = (args['location'] ?? '').toString();
  final notes = (args['notes'] ?? '').toString();

  final decision = await ref.read(actionAutonomyPolicyProvider).evaluateSend(
        channel: 'calendar',
        recipientLabel: title,
      );

  if (decision.canAutoSend) {
    final ok = await ref
        .read(actionPreferencesProvider.notifier)
        .recordFullAutoSend();
    if (ok) {
      await device.insertCalendarEvent(
        title: title,
        startIso: startIso,
        endIso: endIso,
        location: location,
        notes: notes,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final phone = ref.read(phoneControlControllerProvider.notifier);
      return phone.clickText(
        'Save',
        surface: PhoneActionSurface.openClawConfirmed,
      );
    }
  }

  return ref.read(openClawQueueProvider.notifier).enqueueCompose(
        kind: 'save_calendar',
        title: 'Calendar: $title',
        channel: 'calendar',
        recipient: title,
        number: '',
        body: notes,
        subject: startIso,
        extra: {
          'end_iso': endIso,
          'location': location,
        },
      );
}

Future<String> _legacySend(
  Ref ref,
  DeviceActions device,
  String app,
  String number,
  String text,
) async {
  final decision = await ref.read(actionAutonomyPolicyProvider).evaluateSend(
        channel: app,
        recipientLabel: number,
        recipientValue: number,
      );
  if (decision.canAutoSend) {
    return _autoSendMessage(ref, app, number, text);
  }
  return device.sendMessage(app: app, number: number, text: text);
}

String? _extractPhone(String found) {
  final match = RegExp(r'(\+?\d[\d\s().-]{6,}\d)').firstMatch(found);
  return match?.group(1)?.replaceAll(RegExp(r'[^\d+]'), '');
}

bool _isHighImpactClick(String text) {
  return RegExp(
    r'\b(send|pay|confirm|approve|install|buy|purchase|transfer|delete|allow|grant|save)\b',
    caseSensitive: false,
  ).hasMatch(text);
}

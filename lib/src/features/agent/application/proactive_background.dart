import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _kTaskName = 'alter.proactive.nudge';
const _kUniqueName = 'alter-proactive-periodic';
const _kPrefsGateway = 'alter.bg.gateway';
const _kPrefsUserId = 'alter.bg.user_id';
const _kChannelId = 'alter_proactive';
const _kChannelName = 'ALTER Suggestions';

/// WorkManager entry point. Runs in a headless background isolate, so it can
/// only use plugins + plain Dart — no Riverpod/Supabase context. It reads the
/// gateway + user id the app persisted, fetches one fresh, tailored nudge, and
/// posts a local notification. Failures are swallowed so the OS scheduler isn't
/// thrashed.
@pragma('vm:entry-point')
void proactiveCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gateway = (prefs.getString(_kPrefsGateway) ?? '').trim();
      final userId = (prefs.getString(_kPrefsUserId) ?? '').trim();
      if (gateway.isEmpty) return true;

      final nudge = await _fetchNudge(gateway, userId);
      if (nudge == null) return true;
      await _showNudge(nudge.$1, nudge.$2);
      return true;
    } catch (_) {
      return true;
    }
  });
}

Future<(String, String)?> _fetchNudge(String gateway, String userId) async {
  final base = gateway.endsWith('/')
      ? gateway.substring(0, gateway.length - 1)
      : gateway;

  // 1) Today's focus / first open task from the live day feed.
  if (userId.isNotEmpty) {
    try {
      final r = await http
          .get(Uri.parse('$base/v1/life-feed?user_id=$userId'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data is Map) {
          final focus = (data['focus_title'] ?? '').toString().trim();
          var task = '';
          final tasks = data['tasks'];
          if (tasks is List) {
            for (final t in tasks) {
              if (t is Map && t['done'] != true) {
                task = (t['title'] ?? '').toString().trim();
                if (task.isNotEmpty) break;
              }
            }
          }
          if (focus.isNotEmpty || task.isNotEmpty) {
            final title = focus.isEmpty ? 'Your day' : focus;
            final body = task.isNotEmpty ? 'Next up: $task' : focus;
            return (title, body);
          }
        }
      }
    } catch (_) {}
  }

  // 2) Fallback: surface a top opportunity.
  try {
    final r = await http
        .post(
          Uri.parse('$base/v1/opportunities/pipeline'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'profile': <String, dynamic>{}}),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) {
      final opp = _firstOpportunity(jsonDecode(r.body));
      if (opp != null) return ('Worth a look', opp);
    }
  } catch (_) {}

  return null;
}

String? _firstOpportunity(dynamic data) {
  List<dynamic>? list;
  if (data is Map) {
    final crawl = data['crawl'];
    if (crawl is Map && crawl['raw_opportunities'] is List) {
      list = crawl['raw_opportunities'] as List;
    } else if (data['opportunities'] is List) {
      list = data['opportunities'] as List;
    } else if (data['pipeline'] is List) {
      list = data['pipeline'] as List;
    }
  }
  if (list == null || list.isEmpty) return null;
  final first = list.first;
  if (first is! Map) return null;
  final title = (first['title'] ?? '').toString().trim();
  if (title.isEmpty) return null;
  final org = (first['organization'] ?? '').toString().trim();
  return org.isEmpty ? title : '$title — $org';
}

Future<void> _showNudge(String title, String body) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    id: 7301,
    title: 'ALTER • $title',
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: 'Proactive, tailored nudges from ALTER.',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
    ),
  );
}

/// Main-isolate helpers: schedule the periodic pass and feed it the context it
/// needs (gateway URL + user id) via shared prefs.
class ProactiveBackground {
  /// Register the WorkManager callback + a ~6h periodic nudge task, and ask for
  /// the Android 13+ notifications permission. Safe to call once at startup.
  static Future<void> init() async {
    try {
      await Workmanager().initialize(proactiveCallbackDispatcher);
      try {
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
      await Workmanager().registerPeriodicTask(
        _kUniqueName,
        _kTaskName,
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Background scheduling is best-effort; the in-app proactive strip still
      // works without it.
    }
  }

  /// Persist the gateway + user id so the headless isolate can reach the
  /// backend on the user's behalf.
  static Future<void> persistContext({
    required String gateway,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (gateway.trim().isNotEmpty) {
      await prefs.setString(_kPrefsGateway, gateway.trim());
    }
    if (userId != null && userId.trim().isNotEmpty) {
      await prefs.setString(_kPrefsUserId, userId.trim());
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alter/src/core/config/alter_gateway_config.dart';
import 'package:alter/src/core/config/alter_supabase_config.dart';
import 'package:alter/src/features/agent/application/proactive_background.dart';

import 'src/app/alter_app.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  if (!kIsWeb) {
    try {
      await FlutterGemma.initialize();
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();
  AlterUiTheme.isLight.value = prefs.getBool('alter_theme_light') ?? false;
  await AlterGatewayConfig.loadFromPrefs();

  if (AlterSupabaseConfig.isEnabled) {
    await AlterSupabaseConfig.initialize();
  }

  if (!kIsWeb && prefs.getBool('alter_online_assistant') == true) {
    await ProactiveBackground.init();
  }

  runApp(const ProviderScope(child: AlterApp()));
}

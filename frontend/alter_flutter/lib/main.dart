import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/ftue.dart';
import 'screens/onboarding.dart';
import 'screens/main_shell.dart';

void main() => runApp(const AlterApp());

class AlterApp extends StatelessWidget {
  const AlterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlterTheme.isLight,
      builder: (_, light, __) => MaterialApp(
        title: 'Alter',
        debugShowCheckedModeBanner: false,
        theme: buildAlterTheme(light),
        initialRoute: Routes.ftueWhat,
        routes: {
          Routes.ftueWhat: (_) => const FtueWhatScreen(),
          Routes.features: (_) => const FeaturePagesScreen(),
          Routes.getStarted: (_) => const GetStartedScreen(),
          Routes.login: (_) => const LoginScreen(),
          Routes.languages: (_) => const LanguagesScreen(),
          Routes.about: (_) => const AboutYouScreen(),
          Routes.home: (_) => const MainShell(),
        },
      ),
    );
  }
}

class Routes {
  static const ftueWhat = '/';
  static const features = '/features';
  static const getStarted = '/get-started';
  static const login = '/login';
  static const languages = '/languages';
  static const about = '/about';
  static const home = '/home';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/agent/presentation/agent_screen.dart';
import '../features/agent/presentation/live_feed_screen.dart';
import '../features/backend/presentation/backend_feature_hub_screen.dart';
import '../features/backend/presentation/council_os_screen.dart';
import '../features/backend/presentation/future_sim_os_screen.dart';
import '../features/backend/presentation/life_feed_os_screen.dart';
import '../features/backend/presentation/opportunity_os_screen.dart';
import '../features/contextos/presentation/context_mission_control_screen.dart';
import '../features/contextos/presentation/contextos_home_screen.dart';
import '../features/contextos/presentation/daytwin_screen.dart';
import '../features/contextos/presentation/decision_council_screen.dart';
import '../features/contextos/presentation/decision_dna_screen.dart';
import '../features/contextos/presentation/digital_twin_screen.dart';
import '../features/contextos/presentation/edge_model_screen.dart';
import '../features/contextos/presentation/futuretwin_screen.dart';
import '../features/contextos/presentation/lifeshield_screen.dart';
import '../features/contextos/presentation/openclaw_queue_screen.dart';
import '../features/contextos/presentation/privacy_screen.dart';
import '../features/integrations/presentation/integrations_screen.dart';
import '../features/privacy/presentation/data_management_screen.dart';
import '../features/reputation/presentation/reputation_dashboard_screen.dart';
import '../features/settings/presentation/language_settings_screen.dart';
import '../features/settings/presentation/performance_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/voice/presentation/offline_voice_models_screen.dart';
import '../features/auth/presentation/pin_setup_screen.dart';
import '../features/auth/presentation/pin_unlock_screen.dart';
import 'bootstrap_route.dart';
import 'router_refresh.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/home/presentation/main_shell.dart' as contextos_shell;
import '../features/permissions/presentation/permission_hub_screen.dart';
import '../features/profile/application/profile_provider.dart';
import '../ui/routes.dart';
import '../ui/theme.dart';
import '../features/council/presentation/clone_council_screen.dart'
    as council_ui;
import '../features/lens/presentation/alter_lens_screen.dart' as lens_ui;
import '../features/simulator/presentation/future_simulator_screen.dart'
    as simulator_ui;
import '../features/opportunity/presentation/opportunity_radar_screen.dart'
    as radar_ui;
import '../features/social/presentation/social_graph_screen.dart' as social_ui;
import '../features/nfc/presentation/nfc_networking_screen.dart' as nfc_ui;
import '../features/contextos/presentation/memory_screen.dart';
import '../ui/screens/deep.dart';
import '../ui/screens/ftue.dart';
import '../ui/screens/main_shell.dart';
import '../ui/screens/onboarding.dart';
import '../ui/screens/profile_edit.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: AlterRoutes.ftueWhat,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(localAuthServiceProvider);
      final path = state.uri.path;
      final profileAsync = ref.read(userProfileProvider);
      final onboardingDone = profileAsync.asData?.value?.onboardingDone == true;

      return BootstrapRoute.redirect(
        auth: authState,
        path: path,
        onboardingDone: onboardingDone,
        profileLoading:
            authState == LocalAuthState.unlocked && profileAsync.isLoading,
      );
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
    routes: [
      GoRoute(
        path: AlterRoutes.ftueWhat,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const FtueWhatScreen()),
      ),
      GoRoute(
        path: AlterRoutes.features,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const FeaturePagesScreen()),
      ),
      GoRoute(
        path: AlterRoutes.getStarted,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const GetStartedScreen()),
      ),
      GoRoute(
        path: AlterRoutes.pinSetup,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const PinSetupScreen()),
      ),
      GoRoute(
        path: AlterRoutes.pinUnlock,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const PinUnlockScreen()),
      ),
      GoRoute(
        path: AlterRoutes.permissions,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const PermissionHubScreen()),
      ),
      GoRoute(
        path: AlterRoutes.languages,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const LanguagesScreen()),
      ),
      GoRoute(
        path: AlterRoutes.about,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const AboutYouScreen()),
      ),
      GoRoute(
        path: AlterRoutes.home,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const MainShell()),
      ),
      GoRoute(
        path: AlterRoutes.profileEdit,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const ProfileEditScreen()),
      ),
      GoRoute(
        path: AlterRoutes.council,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const council_ui.CloneCouncilScreen()),
      ),
      GoRoute(
        path: AlterRoutes.simulator,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const simulator_ui.FutureSimulatorScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.radar,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const radar_ui.OpportunityRadarScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.social,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const social_ui.SocialGraphScreen()),
      ),
      GoRoute(
        path: AlterRoutes.deepAnalysis,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const DeepAnalysisScreen()),
      ),
      GoRoute(
        path: AlterRoutes.lens,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const lens_ui.AlterLensScreen()),
      ),
      GoRoute(
        path: AlterRoutes.nfc,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const nfc_ui.NfcNetworkingScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.openclaw,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const OpenClawQueueScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.agent,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const AgentScreen()),
      ),
      GoRoute(
        path: AlterRoutes.backend,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const BackendFeatureHubScreen(),
        ),
      ),
      GoRoute(
        path: '${AlterRoutes.backend}/council',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const CouncilOsScreen(),
        ),
      ),
      GoRoute(
        path: '${AlterRoutes.backend}/future-sim',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const FutureSimOsScreen(),
        ),
      ),
      GoRoute(
        path: '${AlterRoutes.backend}/life-feed',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const LifeFeedOsScreen(),
        ),
      ),
      GoRoute(
        path: '${AlterRoutes.backend}/opportunity',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const OpportunityOsScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.integrations,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const IntegrationsScreen()),
      ),
      GoRoute(
        path: AlterRoutes.dataManagement,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const DataManagementScreen()),
      ),
      GoRoute(
        path: AlterRoutes.languageSettings,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const LanguageSettingsScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.settings,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: AlterRoutes.performance,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const PerformanceScreen()),
      ),
      GoRoute(
        path: AlterRoutes.offlineVoiceModels,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const OfflineVoiceModelsScreen(),
        ),
      ),
      GoRoute(
        path: AlterRoutes.memory,
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const MemoryScreen()),
      ),
      GoRoute(
        path: AlterRoutes.voice,
        redirect: (context, state) => AlterRoutes.home,
      ),
      ShellRoute(
        builder: (context, state, child) => contextos_shell.MainShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: AlterRoutes.contextHub,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const ContextOsHomeScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.twin,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const DigitalTwinScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.feed,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const LiveFeedScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.shield,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const LifeShieldScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.dayTwin,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const DayTwinScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.futureTwin,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const FutureTwinScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.decisionCouncil,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const DecisionCouncilScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.dna,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const DecisionDnaScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.edge,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const EdgeModelScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.privacy,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const PrivacyScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.mission,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const ContextMissionControlScreen(),
            ),
          ),
          GoRoute(
            path: AlterRoutes.reputation,
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              child: const ReputationDashboardScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: ColoredBox(color: AppColors.bg, child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

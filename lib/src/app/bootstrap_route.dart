import '../features/auth/application/auth_provider.dart';
import '../ui/routes.dart';

/// First-run navigation (local PIN vault, no cloud login):
///
/// FTUE → PIN setup → Permissions → Languages → About You → Home
abstract final class BootstrapRoute {
  static const ftuePaths = {
    AlterRoutes.ftueWhat,
    AlterRoutes.features,
    AlterRoutes.getStarted,
  };

  static const vaultSetupPaths = {
    AlterRoutes.pinSetup,
  };

  static const profileSetupPaths = {
    AlterRoutes.permissions,
    AlterRoutes.languages,
    AlterRoutes.about,
  };

  static const allFirstRunPaths = {
    ...ftuePaths,
    ...vaultSetupPaths,
    ...profileSetupPaths,
    AlterRoutes.pinUnlock,
    AlterRoutes.login,
  };

  /// Returns a redirect target, or `null` if [path] may be shown.
  static String? redirect({
    required LocalAuthState auth,
    required String path,
    required bool onboardingDone,
    required bool profileLoading,
  }) {
    if (path == AlterRoutes.login) {
      return auth == LocalAuthState.locked
          ? AlterRoutes.pinUnlock
          : AlterRoutes.pinSetup;
    }

    if (auth == LocalAuthState.bootstrapping) {
      if (allFirstRunPaths.contains(path)) return null;
      return AlterRoutes.ftueWhat;
    }

    if (auth == LocalAuthState.pinNotConfigured) {
      if (ftuePaths.contains(path) || path == AlterRoutes.pinSetup) {
        return null;
      }
      return AlterRoutes.ftueWhat;
    }

    if (auth == LocalAuthState.locked) {
      if (path == AlterRoutes.pinUnlock) return null;
      return AlterRoutes.pinUnlock;
    }

    if (profileLoading) return null;

    if (onboardingDone) {
      if (allFirstRunPaths.contains(path)) {
        return AlterRoutes.home;
      }
      return null;
    }

    if (path == AlterRoutes.home || _requiresOnboarding(path)) {
      return AlterRoutes.permissions;
    }

    if (ftuePaths.contains(path) ||
        vaultSetupPaths.contains(path) ||
        path == AlterRoutes.pinUnlock) {
      return AlterRoutes.permissions;
    }

    if (profileSetupPaths.contains(path)) return null;

    return AlterRoutes.permissions;
  }

  static bool _requiresOnboarding(String path) {
    if (path.startsWith('/context') ||
        path == AlterRoutes.council ||
        path == AlterRoutes.simulator ||
        path == AlterRoutes.radar ||
        path == AlterRoutes.social ||
        path == AlterRoutes.lens ||
        path == AlterRoutes.nfc ||
        path == AlterRoutes.agent ||
        path == AlterRoutes.settings ||
        path == AlterRoutes.performance ||
        path == AlterRoutes.memory ||
        path == AlterRoutes.edge) {
      return true;
    }
    return false;
  }
}

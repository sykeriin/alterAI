import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/application/profile_provider.dart';
import '../data/backend_api_client.dart';
import 'backend_config_controller.dart';

String? _userId() => Supabase.instance.client.auth.currentUser?.id;

/// Live "Life Feed" from the deployed gateway (`/v1/life-feed`). Real backend
/// data — greeting, focus, tasks. No mock.
final lifeFeedProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final cfg = await ref.watch(backendConfigProvider.future);
  if (!cfg.hasGateway) return null;
  final uid = _userId();
  if (uid == null) return null;
  final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
  ref.onDispose(client.close);
  return client.getJson('/v1/life-feed?user_id=$uid');
});

class FutureTwinState {
  const FutureTwinState({
    this.objective = '',
    this.loading = false,
    this.result,
    this.error = '',
  });

  final String objective;
  final bool loading;
  final Map<String, dynamic>? result;
  final String error;

  FutureTwinState copyWith({
    String? objective,
    bool? loading,
    Map<String, dynamic>? result,
    String? error,
  }) =>
      FutureTwinState(
        objective: objective ?? this.objective,
        loading: loading ?? this.loading,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

/// Future Simulator wired to `/v1/intelligence/future-twin` (real gateway).
final futureTwinProvider =
    NotifierProvider<FutureTwinNotifier, FutureTwinState>(
        FutureTwinNotifier.new);

class FutureTwinNotifier extends Notifier<FutureTwinState> {
  @override
  FutureTwinState build() => const FutureTwinState();

  void setObjective(String v) => state = state.copyWith(objective: v, error: '');

  Future<void> simulate() async {
    final obj = state.objective.trim();
    if (obj.length < 4) {
      state = state.copyWith(error: 'Describe the path you want to simulate.');
      return;
    }
    final cfg = await ref.read(backendConfigProvider.future);
    if (!cfg.hasGateway) {
      state = state.copyWith(error: 'No backend gateway configured.');
      return;
    }
    final profile = ref.read(userProfileProvider).asData?.value;
    final client = BackendApiClient(baseUrl: cfg.gatewayUrl);
    state = state.copyWith(loading: true, error: '');
    try {
      final body = await client.postJson('/v1/intelligence/future-twin', {
        'objective': obj,
        'user_profile': {
          'name': profile?.displayName ?? '',
          'current_role': profile?.role ?? '',
          'industry': profile?.industry ?? '',
        },
        'skills': profile?.skills ?? const <String>[],
        'goals': profile?.goals ?? const <String>[],
        'interests': profile?.interests ?? const <String>[],
        'horizon_days': 90,
        'write_memory': false,
      });
      state = state.copyWith(loading: false, result: body);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      client.close();
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/alter_models.dart' as alter;
import '../../profile/application/profile_provider.dart';
import '../data/backend_feature_api_client.dart';
import 'backend_config_controller.dart';

/// Clone Council agents — live from `/v1/clone-council/agents` via the gateway
/// proxy. No mock.
final cloneAgentsProvider =
    FutureProvider.autoDispose<List<alter.CloneAgent>>((ref) async {
  final cfg = await ref.watch(backendConfigProvider.future);
  if (!cfg.hasGateway) return const [];
  final client = BackendFeatureApiClient(baseUrl: cfg.gatewayUrl);
  ref.onDispose(client.close);
  return client.fetchCloneAgents();
});

/// Opportunity Radar — live from `/v1/opportunities/pipeline`. Returns empty
/// until the user's profile has skills/goals/interests (honest, not mock).
final opportunitiesProvider =
    FutureProvider.autoDispose<List<alter.OpportunitySignal>>((ref) async {
  final cfg = await ref.watch(backendConfigProvider.future);
  if (!cfg.hasGateway) return const [];
  final profile = ref.watch(userProfileProvider).asData?.value;
  final client = BackendFeatureApiClient(baseUrl: cfg.gatewayUrl);
  ref.onDispose(client.close);
  return client.fetchOpportunities(profile: profile);
});

class CouncilDebateState {
  const CouncilDebateState({
    this.topic = '',
    this.loading = false,
    this.debate,
    this.error = '',
  });

  final String topic;
  final bool loading;
  final BackendCouncilDebate? debate;
  final String error;

  CouncilDebateState copyWith({
    String? topic,
    bool? loading,
    BackendCouncilDebate? debate,
    String? error,
  }) =>
      CouncilDebateState(
        topic: topic ?? this.topic,
        loading: loading ?? this.loading,
        debate: debate ?? this.debate,
        error: error ?? this.error,
      );
}

/// Council debate wired to `/v1/clone-council/debate`.
final councilDebateProvider =
    NotifierProvider<CouncilDebateNotifier, CouncilDebateState>(
        CouncilDebateNotifier.new);

class CouncilDebateNotifier extends Notifier<CouncilDebateState> {
  @override
  CouncilDebateState build() => const CouncilDebateState();

  void setTopic(String v) => state = state.copyWith(topic: v, error: '');

  Future<void> run() async {
    final topic = state.topic.trim();
    if (topic.length < 4) {
      state = state.copyWith(error: 'Ask the council a question.');
      return;
    }
    final cfg = await ref.read(backendConfigProvider.future);
    if (!cfg.hasGateway) {
      state = state.copyWith(error: 'No backend gateway configured.');
      return;
    }
    final profile = ref.read(userProfileProvider).asData?.value;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final client = BackendFeatureApiClient(baseUrl: cfg.gatewayUrl);
    state = state.copyWith(loading: true, error: '');
    try {
      final debate = await client.runCouncilDebate(
        topic: topic,
        profile: profile,
        userId: userId,
      );
      state = state.copyWith(loading: false, debate: debate);
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

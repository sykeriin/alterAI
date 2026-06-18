import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../../domain/entities/alter_models.dart';
import '../../../domain/repositories/alter_repository.dart';
import '../../../data/local/dao_providers.dart';
import '../../../data/local/life_os_dao.dart';
import '../../../data/repositories/sqlite_alter_repository.dart';

const _emptyBrief = AssistantBrief(
  greeting: '',
  focus: '',
  nextAction: '',
  signals: [],
);

final alterRepositoryProvider = Provider<AlterRepository>((ref) {
  final dao = ref.watch(lifeOsDaoProvider);
  return SqliteAlterRepository(
    dao,
    () => ref.read(localUserIdProvider),
  );
});

Future<T> _whenUnlocked<T>(
  Ref ref,
  Future<T> Function(AlterRepository repo) load,
  T empty,
) async {
  ref.watch(isDbUnlockedProvider);
  if (ref.read(localUserIdProvider) == null) return empty;
  try {
    return await load(ref.read(alterRepositoryProvider));
  } catch (_) {
    return empty;
  }
}

final assistantBriefProvider = FutureProvider<AssistantBrief>((ref) async {
  return _whenUnlocked(
    ref,
    (repo) => repo.loadAssistantBrief(),
    _emptyBrief,
  );
});

final cloneCouncilProvider = FutureProvider<List<CloneAgent>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadCloneCouncil(), const []);
});

final futureScenariosProvider = FutureProvider<List<FutureScenario>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadFutureScenarios(), const []);
});

final opportunitySignalsProvider =
    FutureProvider<List<OpportunitySignal>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadOpportunitySignals(), const []);
});

final socialGraphProvider = FutureProvider<List<SocialContact>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadSocialGraph(), const []);
});

final reputationEventsProvider =
    FutureProvider<List<ReputationEvent>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadReputationEvents(), const []);
});

final lensInsightsProvider = FutureProvider<List<LensInsight>>((ref) async {
  return _whenUnlocked(ref, (repo) => repo.loadLensInsights(), const []);
});

/// Mutations for Life OS tables (screens call these then invalidate providers).
final lifeOsMutationsProvider = Provider<LifeOsMutations>((ref) {
  return LifeOsMutations(ref);
});

class LifeOsMutations {
  LifeOsMutations(this._ref);

  final Ref _ref;

  LifeOsDao get _dao => _ref.read(lifeOsDaoProvider);

  String? get _userId => _ref.read(localUserIdProvider);

  Future<void> appendSocialContact(SocialContact contact) async {
    final userId = _userId;
    if (userId == null) return;
    final existing = await _dao.loadSocialGraph(userId);
    await _dao.replaceSocialGraph(userId, [...existing, contact]);
  }

  Future<void> deleteSocialContactByName(String name) async {
    final userId = _userId;
    if (userId == null) return;
    final existing = await _dao.loadSocialGraph(userId);
    await _dao.replaceSocialGraph(
      userId,
      existing.where((c) => c.name != name).toList(),
    );
  }

  Future<void> replaceFutureScenarios(List<FutureScenario> scenarios) async {
    final userId = _userId;
    if (userId == null) return;
    await _dao.replaceFutureScenarios(userId, scenarios);
  }

  Future<void> insertReputationEvent(ReputationEvent event) async {
    final userId = _userId;
    if (userId == null) return;
    await _dao.insertReputationEvent(userId, event);
  }

  Future<void> replaceCloneCouncil(List<CloneAgent> agents) async {
    final userId = _userId;
    if (userId == null) return;
    await _dao.replaceCloneCouncil(userId, agents);
  }
}

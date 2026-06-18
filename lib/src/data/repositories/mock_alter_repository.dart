import '../../domain/entities/alter_models.dart';
import '../../domain/repositories/alter_repository.dart';

/// Empty mock — no invented data; used when Supabase is unavailable.
class MockAlterRepository implements AlterRepository {
  const MockAlterRepository();

  static const _emptyBrief = AssistantBrief(
    greeting: '',
    focus: '',
    nextAction: '',
    signals: [],
  );

  @override
  Future<AssistantBrief> loadAssistantBrief() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _emptyBrief;
  }

  @override
  Future<List<CloneAgent>> loadCloneCouncil() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }

  @override
  Future<List<FutureScenario>> loadFutureScenarios() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }

  @override
  Future<List<OpportunitySignal>> loadOpportunitySignals() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }

  @override
  Future<List<SocialContact>> loadSocialGraph() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }

  @override
  Future<List<ReputationEvent>> loadReputationEvents() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }

  @override
  Future<List<LensInsight>> loadLensInsights() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const [];
  }
}

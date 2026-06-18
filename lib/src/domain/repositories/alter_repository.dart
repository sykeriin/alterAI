import '../entities/alter_models.dart';

abstract class AlterRepository {
  Future<AssistantBrief> loadAssistantBrief();

  Future<List<CloneAgent>> loadCloneCouncil();

  Future<List<FutureScenario>> loadFutureScenarios();

  Future<List<OpportunitySignal>> loadOpportunitySignals();

  Future<List<SocialContact>> loadSocialGraph();

  Future<List<ReputationEvent>> loadReputationEvents();

  Future<List<LensInsight>> loadLensInsights();
}

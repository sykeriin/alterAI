import '../../domain/entities/alter_models.dart';
import '../../domain/repositories/alter_repository.dart';
import '../local/life_os_dao.dart';

class SqliteAlterRepository implements AlterRepository {
  SqliteAlterRepository(this._dao, this._userId);

  final LifeOsDao _dao;
  final String? Function() _userId;

  String get _uid {
    final id = _userId();
    if (id == null || id.isEmpty) {
      throw StateError('User not unlocked');
    }
    return id;
  }

  @override
  Future<AssistantBrief> loadAssistantBrief() =>
      _dao.loadAssistantBrief(_uid);

  @override
  Future<List<CloneAgent>> loadCloneCouncil() =>
      _dao.loadCloneCouncil(_uid);

  @override
  Future<List<FutureScenario>> loadFutureScenarios() =>
      _dao.loadFutureScenarios(_uid);

  @override
  Future<List<OpportunitySignal>> loadOpportunitySignals() =>
      _dao.loadOpportunitySignals(_uid);

  @override
  Future<List<SocialContact>> loadSocialGraph() =>
      _dao.loadSocialGraph(_uid);

  @override
  Future<List<ReputationEvent>> loadReputationEvents() =>
      _dao.loadReputationEvents(_uid);

  @override
  Future<List<LensInsight>> loadLensInsights() =>
      _dao.loadLensInsights(_uid);
}

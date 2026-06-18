import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import 'contextos_dao.dart';
import 'conversation_dao.dart';
import 'embedding_dao.dart';
import 'identity_dao.dart';
import 'life_os_dao.dart';
import 'memory_dao.dart';
import 'memory_governance_dao.dart';
import 'app_settings_dao.dart';
import 'profile_dao.dart';

final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return AppSettingsDao(ref.watch(alterDatabaseProvider));
});

final profileDaoProvider = Provider<ProfileDao>((ref) {
  return ProfileDao(ref.watch(alterDatabaseProvider));
});

final memoryDaoProvider = Provider<MemoryDao>((ref) {
  return MemoryDao(ref.watch(alterDatabaseProvider));
});

final embeddingDaoProvider = Provider<EmbeddingDao>((ref) {
  return EmbeddingDao(ref.watch(alterDatabaseProvider));
});

final identityDaoProvider = Provider<IdentityDao>((ref) {
  return IdentityDao(ref.watch(alterDatabaseProvider));
});

final memoryGovernanceDaoProvider = Provider<MemoryGovernanceDao>((ref) {
  return MemoryGovernanceDao(ref.watch(alterDatabaseProvider));
});

final contextOsDaoProvider = Provider<ContextOsDao>((ref) {
  return ContextOsDao(ref.watch(alterDatabaseProvider));
});

final lifeOsDaoProvider = Provider<LifeOsDao>((ref) {
  return LifeOsDao(ref.watch(alterDatabaseProvider));
});

final conversationDaoProvider = Provider<ConversationDao>((ref) {
  return ConversationDao(ref.watch(alterDatabaseProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alter_database.dart';
import 'database_key_service.dart';

final databaseKeyServiceProvider = Provider<DatabaseKeyService>((ref) {
  return DatabaseKeyService();
});

final alterDatabaseProvider = Provider<AlterDatabase>((ref) {
  return AlterDatabase.instance;
});

final isPinConfiguredProvider = FutureProvider<bool>((ref) async {
  return ref.watch(databaseKeyServiceProvider).isPinConfigured();
});

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../features/contextos/application/memory_engine.dart';

class MemoryGovernanceDao {
  MemoryGovernanceDao(this._db);

  final AlterDatabase _db;

  Future<MemoryGovernanceSettings?> get(String userId) async {
    final rows = await _db.db.query(
      'memory_governance_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> upsert(String userId, MemoryGovernanceSettings settings) async {
    await _db.db.insert(
      'memory_governance_settings',
      {
        'user_id': userId,
        'default_retention': settings.defaultRetention,
        'durable_requires_confirmation':
            dbBoolInt(settings.durableRequiresConfirmation),
        'sensitive_requires_confirmation':
            dbBoolInt(settings.sensitiveRequiresConfirmation),
        'restricted_storage_allowed':
            dbBoolInt(settings.restrictedStorageAllowed),
        'portable_export_enabled': dbBoolInt(settings.portableExportEnabled),
        'max_retrieval_chars': settings.maxRetrievalChars,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  MemoryGovernanceSettings _fromRow(Map<String, Object?> row) {
    return MemoryGovernanceSettings(
      defaultRetention: row['default_retention'] as String? ?? 'ephemeral',
      durableRequiresConfirmation: dbBool(row['durable_requires_confirmation']),
      sensitiveRequiresConfirmation:
          dbBool(row['sensitive_requires_confirmation']),
      restrictedStorageAllowed: dbBool(row['restricted_storage_allowed']),
      portableExportEnabled: dbBool(row['portable_export_enabled']),
      maxRetrievalChars: (row['max_retrieval_chars'] as num?)?.toInt() ?? 6000,
    );
  }
}

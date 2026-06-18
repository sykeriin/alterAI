import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../features/identity/domain/identity_trait.dart';

class IdentityDao {
  IdentityDao(this._db);

  final AlterDatabase _db;
  static const _uuid = Uuid();

  Future<List<IdentityTrait>> list(String userId) async {
    final rows = await _db.db.query(
      'identity_traits',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'dimension ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(IdentityTrait trait) async {
    final id = trait.id ?? _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _db.db.insert(
      'identity_traits',
      {
        'id': id,
        'user_id': trait.userId,
        'dimension': trait.dimension,
        'value': trait.value,
        'confidence': trait.confidence,
        'source_memory_ids': encodeStringList(trait.sourceMemoryIds),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  IdentityTrait _fromRow(Map<String, Object?> row) {
    return IdentityTrait(
      id: row['id'] as String?,
      userId: row['user_id'] as String? ?? '',
      dimension: row['dimension'] as String? ?? '',
      value: row['value'] as String? ?? '',
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0.5,
      sourceMemoryIds: decodeStringList(row['source_memory_ids']),
    );
  }
}

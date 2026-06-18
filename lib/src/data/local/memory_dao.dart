import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../features/memory/domain/memory_item.dart';

class MemoryDao {
  MemoryDao(this._db);

  final AlterDatabase _db;
  static const _uuid = Uuid();

  static const _activeWhere =
      'user_id = ? AND retention != ? AND (expires_at IS NULL OR expires_at > ?)';

  Future<List<MemoryItem>> listActive(String userId, int limit) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.db.query(
      'memories',
      where: _activeWhere,
      whereArgs: [userId, MemoryRetention.immediateDelete.name, now],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// Unconfirmed active memories for the swipe review deck.
  Future<List<MemoryItem>> listUnconfirmed(String userId, int limit) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.db.query(
      'memories',
      where: '$_activeWhere AND confirmed = 0',
      whereArgs: [userId, MemoryRetention.immediateDelete.name, now],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// Pending first, then confirmed — for full re-curation mode.
  Future<List<MemoryItem>> listReviewQueue(String userId, int limit) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.db.query(
      'memories',
      where: _activeWhere,
      whereArgs: [userId, MemoryRetention.immediateDelete.name, now],
      orderBy: 'confirmed ASC, created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// Confirmed durable memories for browse-kept list.
  Future<List<MemoryItem>> listKept(String userId, int limit) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.db.query(
      'memories',
      where: '$_activeWhere AND confirmed = 1',
      whereArgs: [userId, MemoryRetention.immediateDelete.name, now],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countPendingReview(String userId) async {
    final now = DateTime.now().toIso8601String();
    final count = Sqflite.firstIntValue(
      await _db.db.rawQuery(
        'SELECT COUNT(*) FROM memories WHERE $_activeWhere AND confirmed = 0',
        [userId, MemoryRetention.immediateDelete.name, now],
      ),
    );
    return count ?? 0;
  }

  Future<void> deleteAllForUser(String userId) async {
    await _db.db.rawDelete(
      'DELETE FROM memory_embeddings WHERE memory_id IN '
      '(SELECT id FROM memories WHERE user_id = ?)',
      [userId],
    );
    await _db.db.delete('memories', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<MemoryItem> insert(MemoryItem item) async {
    final saved = _prepareInsert(item);
    await _db.db.insert('memories', saved.row);
    return saved.item;
  }

  Future<MemoryItem> insertTxn(Transaction txn, MemoryItem item) async {
    final saved = _prepareInsert(item);
    await txn.insert('memories', saved.row);
    return saved.item;
  }

  Future<void> update(MemoryItem item) async {
    final id = item.id;
    if (id == null) return;
    final now = DateTime.now().toIso8601String();
    await _db.db.update(
      'memories',
      {
        'kind': item.kind.name,
        'title': item.title,
        'content': item.content,
        'provenance': item.provenance,
        'confidence': item.confidence,
        'sensitivity': item.sensitivity.name,
        'retention': item.retention.name,
        'expires_at': item.expiresAt?.toIso8601String(),
        'source_ids': encodeStringList(item.sourceIds),
        'confirmed': dbBoolInt(item.confirmed),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await _db.db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> purgeExpired(String userId) async {
    final now = DateTime.now().toIso8601String();
    await _db.db.delete(
      'memories',
      where: 'user_id = ? AND expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: [userId, now],
    );
  }

  Future<MemoryItem?> getById(String id) async {
    final rows = await _db.db.query(
      'memories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  ({MemoryItem item, Map<String, Object?> row}) _prepareInsert(MemoryItem item) {
    final id = item.id ?? _uuid.v4();
    final now = DateTime.now();
    final createdAt = item.createdAt ?? now;
    final saved = MemoryItem(
      id: id,
      userId: item.userId,
      kind: item.kind,
      title: item.title,
      content: item.content,
      provenance: item.provenance,
      confidence: item.confidence,
      sensitivity: item.sensitivity,
      retention: item.retention,
      expiresAt: item.expiresAt,
      sourceIds: item.sourceIds,
      confirmed: item.confirmed,
      createdAt: createdAt,
    );
    return (
      item: saved,
      row: {
        'id': id,
        'user_id': item.userId,
        'kind': item.kind.name,
        'title': item.title,
        'content': item.content,
        'provenance': item.provenance,
        'confidence': item.confidence,
        'sensitivity': item.sensitivity.name,
        'retention': item.retention.name,
        'expires_at': item.expiresAt?.toIso8601String(),
        'source_ids': encodeStringList(item.sourceIds),
        'confirmed': dbBoolInt(item.confirmed),
        'created_at': createdAt.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
  }

  MemoryItem _fromRow(Map<String, Object?> row) {
    return MemoryItem(
      id: row['id'] as String?,
      userId: row['user_id'] as String? ?? '',
      kind: MemoryKind.values.firstWhere(
        (k) => k.name == row['kind'],
        orElse: () => MemoryKind.observation,
      ),
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      provenance: row['provenance'] as String? ?? '',
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0.5,
      sensitivity: MemorySensitivity.values.firstWhere(
        (s) => s.name == row['sensitivity'],
        orElse: () => MemorySensitivity.normal,
      ),
      retention: MemoryRetention.values.firstWhere(
        (r) => r.name == row['retention'],
        orElse: () => MemoryRetention.ephemeral,
      ),
      expiresAt: row['expires_at'] != null
          ? DateTime.tryParse(row['expires_at'].toString())
          : null,
      sourceIds: decodeStringList(row['source_ids']),
      confirmed: dbBool(row['confirmed']),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())
          : null,
    );
  }
}

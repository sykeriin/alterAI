import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/alter_database.dart';
import '../../features/memory/data/hash_embedding.dart';
import '../../features/memory/data/scored_memory_vector.dart';

class EmbeddingDao {
  EmbeddingDao(this._db);

  final AlterDatabase _db;

  Future<void> upsert({
    String? memoryId,
    required String abstractText,
    required String kind,
  }) async {
    if (abstractText.trim().isEmpty) return;
    await _insertRow(_db.db, memoryId: memoryId, abstractText: abstractText, kind: kind);
    await prune();
  }

  Future<void> upsertTxn(
    Transaction txn, {
    String? memoryId,
    required String abstractText,
    required String kind,
  }) async {
    if (abstractText.trim().isEmpty) return;
    await _insertRow(txn, memoryId: memoryId, abstractText: abstractText, kind: kind);
  }

  Future<List<ScoredMemoryVector>> search({
    required String query,
    int limit = 12,
  }) async {
    final rows = await _db.db.query(
      'memory_embeddings',
      orderBy: 'created_at DESC',
      limit: 500,
    );
    if (rows.isEmpty) return const [];

    final qVec = HashEmbedding.embed(query);
    final scored = <ScoredMemoryVector>[];
    for (final row in rows) {
      final blob = row['embedding'] as Uint8List?;
      if (blob == null) continue;
      final floats = Float64List.view(blob.buffer);
      final score = HashEmbedding.cosine(qVec, floats);
      scored.add(
        ScoredMemoryVector(
          abstractText: row['abstract_text']?.toString() ?? '',
          kind: row['kind']?.toString() ?? 'observation',
          score: score,
          memoryId: row['memory_id']?.toString(),
        ),
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  Future<void> deleteByMemoryId(String memoryId) async {
    await _db.db.delete(
      'memory_embeddings',
      where: 'memory_id = ?',
      whereArgs: [memoryId],
    );
  }

  Future<void> prune({int maxRows = 2000}) async {
    final count = Sqflite.firstIntValue(
          await _db.db.rawQuery('SELECT COUNT(*) FROM memory_embeddings'),
        ) ??
        0;
    if (count <= maxRows) return;
    await _db.db.rawDelete(
      '''
      DELETE FROM memory_embeddings WHERE id IN (
        SELECT id FROM memory_embeddings ORDER BY created_at ASC LIMIT ?
      )
      ''',
      [count - maxRows],
    );
  }

  Future<void> _insertRow(
    DatabaseExecutor executor, {
    String? memoryId,
    required String abstractText,
    required String kind,
  }) async {
    final embedding = HashEmbedding.embed(abstractText);
    final blob = Float64List.fromList(embedding).buffer.asUint8List();
    await executor.insert('memory_embeddings', {
      'memory_id': memoryId,
      'abstract_text': abstractText.trim(),
      'kind': kind,
      'embedding': blob,
      'embedding_model': 'hash_v1',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

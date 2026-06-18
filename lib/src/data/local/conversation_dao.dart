import 'package:uuid/uuid.dart';

import '../../core/database/alter_database.dart';

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    this.intent,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String role;
  final String content;
  final String? intent;
  final DateTime createdAt;
}

class ConversationDao {
  ConversationDao(this._db);

  final AlterDatabase _db;
  static const _uuid = Uuid();

  Future<void> append({
    required String userId,
    required String role,
    required String content,
    String? intent,
  }) async {
    await _db.db.insert('conversations', {
      'id': _uuid.v4(),
      'user_id': userId,
      'role': role,
      'content': content,
      'intent': intent,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ConversationEntry>> listRecent(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _db.db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  ConversationEntry _fromRow(Map<String, Object?> row) {
    return ConversationEntry(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      role: row['role'] as String? ?? '',
      content: row['content'] as String? ?? '',
      intent: row['intent'] as String?,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

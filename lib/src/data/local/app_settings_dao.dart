import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/alter_database.dart';

class AppSettingsDao {
  AppSettingsDao(this._db);

  final AlterDatabase _db;

  Future<String?> get(String key) async {
    final rows = await _db.db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, {int fallback = 0}) async {
    final raw = await get(key);
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  Future<void> setInt(String key, int value) => set(key, value.toString());
}

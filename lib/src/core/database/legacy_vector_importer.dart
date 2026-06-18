import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as plain;
import 'package:sqflite_sqlcipher/sqflite.dart';

class LegacyVectorImporter {
  static const _prefsKey = 'alter_legacy_vectors_imported';

  static Future<void> importInto(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) == true) return;

    final dir = await getApplicationDocumentsDirectory();
    final legacyPath = p.join(dir.path, 'alter_memory_vectors.db');
    if (!await plain.databaseFactory.databaseExists(legacyPath)) {
      await prefs.setBool(_prefsKey, true);
      return;
    }

    plain.Database? legacyDb;
    try {
      legacyDb = await plain.openDatabase(legacyPath, readOnly: true);
      final rows = await legacyDb.query('memory_vectors');
      for (final row in rows) {
        await db.insert(
          'memory_embeddings',
          {
            'memory_id': row['memory_id'],
            'abstract_text': row['abstract_text'],
            'kind': row['kind'],
            'embedding': row['embedding'],
            'embedding_model': 'hash_v1',
            'created_at': row['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await legacyDb.close();
      legacyDb = null;
      final migratedPath = '$legacyPath.migrated';
      final file = File(legacyPath);
      if (await file.exists()) {
        await file.rename(migratedPath);
      }
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      await legacyDb?.close();
      await prefs.setBool(_prefsKey, true);
    }
  }
}

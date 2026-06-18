import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_key_service.dart';
import 'legacy_vector_importer.dart';
import 'migrations/migration_v1.dart';

const _dbVersion = 2;

class AlterDatabase {
  AlterDatabase._();
  static AlterDatabase? _instance;
  static AlterDatabase get instance => _instance ??= AlterDatabase._();

  Database? _db;
  String? _path;

  bool get isOpen => _db != null && _db!.isOpen;

  Database get db {
    final database = _db;
    if (database == null || !database.isOpen) {
      throw StateError('AlterDatabase is not open');
    }
    return database;
  }

  Future<void> open(Uint8List encryptionKey) async {
    if (isOpen) return;
    final dir = await getApplicationDocumentsDirectory();
    _path = p.join(dir.path, 'alter.db');
    final password = databasePasswordFromKey(encryptionKey);
    try {
      _db = await _openDb(_path!, password);
    } on DatabaseException catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('not a database') ||
          message.contains('file is not a database')) {
        await _deleteDbFiles(_path!);
        _db = await _openDb(_path!, password);
      } else {
        rethrow;
      }
    }

    await LegacyVectorImporter.importInto(_db!);
  }

  Future<Database> _openDb(String path, String password) {
    return openDatabase(
      path,
      password: password,
      version: _dbVersion,
      onConfigure: (db) async {
        // SQLCipher on Android rejects execute() for PRAGMA; rawQuery is safe.
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, version) async {
        for (final stmt in kMigrationV1Statements) {
          await db.execute(stmt);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          for (final stmt in kMigrationV1Statements) {
            await db.execute(stmt);
          }
        }
        if (oldVersion < 2) {
          await LegacyVectorImporter.importInto(db);
        }
      },
    );
  }

  Future<void> _deleteDbFiles(String path) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    return db.transaction(action);
  }

  Future<void> ensureLocalSession({required String userId}) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'local_session',
      {
        'id': 1,
        'user_id': userId,
        'created_at': now,
        'pin_setup_complete': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readLocalUserId() async {
    final rows =
        await db.query('local_session', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return rows.first['user_id'] as String?;
  }

  Future<void> rekey(Uint8List newKey) async {
    if (!isOpen) return;
    final password = databasePasswordFromKey(newKey);
    await db.execute("PRAGMA rekey = '$password'");
  }
}

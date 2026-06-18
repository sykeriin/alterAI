import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../features/profile/domain/user_profile.dart';

class ProfileDao {
  ProfileDao(this._db);

  final AlterDatabase _db;

  Future<UserProfile?> getByUserId(String userId) async {
    final rows = await _db.db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first, userId);
  }

  Future<void> upsert(UserProfile profile) async {
    final now = DateTime.now().toIso8601String();
    final createdAt = await _readCreatedAt(profile.id) ?? now;
    await _db.db.insert(
      'user_profiles',
      {
        'id': profile.id,
        'display_name': profile.displayName,
        'role': profile.role,
        'career_stage': profile.careerStage,
        'industry': profile.industry,
        'bio': profile.bio,
        'skills': encodeStringList(profile.skills),
        'goals': encodeStringList(profile.goals),
        'interests': encodeStringList(profile.interests),
        'languages': encodeStringList(profile.languages),
        'location': profile.location,
        'availability': profile.availability,
        'openai_key': profile.openaiKey,
        'sarvam_key': profile.sarvamKey,
        'onboarding_done': dbBoolInt(profile.onboardingDone),
        'created_at': createdAt,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateKeys({
    required String userId,
    String? openaiKey,
    String? sarvamKey,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (openaiKey != null) patch['openai_key'] = openaiKey;
    if (sarvamKey != null) patch['sarvam_key'] = sarvamKey;
    if (patch.length == 1) return;

    await _db.db.update(
      'user_profiles',
      patch,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<String?> _readCreatedAt(String userId) async {
    final rows = await _db.db.query(
      'user_profiles',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['created_at'] as String?;
  }

  UserProfile _fromRow(Map<String, Object?> row, String userId) {
    return UserProfile(
      id: userId,
      displayName: row['display_name'] as String? ?? '',
      role: row['role'] as String? ?? '',
      careerStage: row['career_stage'] as String? ?? '',
      industry: row['industry'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      skills: decodeStringList(row['skills']),
      goals: decodeStringList(row['goals']),
      interests: decodeStringList(row['interests']),
      languages: decodeStringList(row['languages']),
      location: row['location'] as String? ?? '',
      availability: row['availability'] as String? ?? '',
      openaiKey: row['openai_key'] as String? ?? '',
      sarvamKey: row['sarvam_key'] as String? ?? '',
      onboardingDone: dbBool(row['onboarding_done']),
    );
  }
}

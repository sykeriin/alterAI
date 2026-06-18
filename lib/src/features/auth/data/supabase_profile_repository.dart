import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/domain/user_profile.dart';

class SupabaseProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson({...row, 'id': userId});
  }

  Future<void> ensureProfileRow(String userId, {String? email}) async {
    final existing = await _client
        .from('user_profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (existing != null) return;

    final displayName = email != null && email.contains('@')
        ? email.split('@').first
        : '';

    await _client.from('user_profiles').insert({
      'id': userId,
      'display_name': displayName,
      'languages': ['English'],
    });
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('user_profiles').upsert({
      'id': profile.id,
      ...profile.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

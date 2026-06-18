import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/dao_providers.dart';
import '../../features/memory/domain/memory_item.dart';
import '../../features/profile/domain/user_profile.dart';

final supabaseImportServiceProvider = Provider<SupabaseImportService>((ref) {
  return SupabaseImportService(ref);
});

class ImportResult {
  const ImportResult({
    required this.memoriesImported,
    required this.profileImported,
    required this.errors,
  });

  final int memoriesImported;
  final bool profileImported;
  final List<String> errors;

  bool get ok => errors.isEmpty;
}

/// Optional one-time import from a Supabase JSON export file.
class SupabaseImportService {
  SupabaseImportService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Expected format: `{ "memories": [...], "user_profiles": {...} }`
  Future<ImportResult> importFromJsonFile(
    String path, {
    required String userId,
  }) async {
    final errors = <String>[];
    var memoriesImported = 0;
    var profileImported = false;

    try {
      final raw = await File(path).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const ImportResult(
          memoriesImported: 0,
          profileImported: false,
          errors: ['Invalid JSON root — expected an object.'],
        );
      }

      final profileJson = json['user_profiles'] ?? json['profile'];
      if (profileJson is Map<String, dynamic>) {
        try {
          final profile = UserProfile.fromJson({
            ...profileJson,
            'id': userId,
          });
          await _ref.read(profileDaoProvider).upsert(profile);
          profileImported = true;
        } catch (e) {
          errors.add('Profile import failed: $e');
        }
      }

      final memories = json['memories'];
      if (memories is List) {
        final dao = _ref.read(memoryDaoProvider);
        for (final item in memories) {
          if (item is! Map<String, dynamic>) continue;
          try {
            final memory = MemoryItem.fromJson({
              ...item,
              'user_id': userId,
              'id': item['id']?.toString() ?? _uuid.v4(),
            });
            await dao.insert(memory);
            memoriesImported++;
          } catch (e) {
            errors.add('Memory skipped: $e');
          }
        }
      }
    } catch (e) {
      errors.add('Import failed: $e');
    }

    return ImportResult(
      memoriesImported: memoriesImported,
      profileImported: profileImported,
      errors: errors,
    );
  }
}

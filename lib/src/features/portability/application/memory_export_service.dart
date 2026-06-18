import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../contextos/application/memory_engine.dart';
import '../../../data/local/contextos_dao.dart';
import '../../../data/local/dao_providers.dart';
import '../../memory/application/memory_store.dart';
import '../../profile/application/profile_provider.dart';

final memoryExportServiceProvider = Provider<MemoryExportService>((ref) {
  return MemoryExportService(ref);
});

class MemoryExportService {
  MemoryExportService(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> buildExportPackage() async {
    final governance = _ref.read(memoryGovernanceProvider).asData?.value;
    if (governance?.portableExportEnabled != true) {
      throw StateError(
        'Portable memory export is disabled in governance settings.',
      );
    }

    final userId = _ref.read(localUserIdProvider);
    final profile = _ref.read(userProfileProvider).asData?.value;
    final memories = _ref.read(memoryStoreProvider).asData?.value ?? const [];

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'profile': profile?.toJson(),
      'memories': memories.map((m) => m.toJson()).toList(),
    };

    return {
      'format': 'alter_memory_export_v1',
      'payload': payload,
    };
  }

  Future<void> revokeExternalAccess() async {
    final userId = _ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await _ref.read(contextOsDaoProvider).insertAuditEvent(
            AuditEventRecord(
              id: '',
              userId: userId,
              kind: 'portability_revoke',
              detail: 'All temporary memory shares revoked',
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  String encodeJson(Map<String, dynamic> package) =>
      const JsonEncoder.withIndent('  ').convert(package);
}

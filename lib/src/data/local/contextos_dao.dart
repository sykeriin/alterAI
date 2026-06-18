import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../features/contextos/application/memory_engine.dart';
import '../../features/contextos/application/preferences_controller.dart';
import '../../features/contextos/domain/digital_twin_models.dart';

class CapturedMomentRecord {
  const CapturedMomentRecord({
    required this.id,
    required this.userId,
    required this.sourceSurface,
    this.sourceType = 'text',
    this.rawExcerpt = '',
    this.redactedText = '',
    this.privateMode = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String sourceSurface;
  final String sourceType;
  final String rawExcerpt;
  final String redactedText;
  final bool privateMode;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'user_id': userId,
        'source_surface': sourceSurface,
        'source_type': sourceType,
        'raw_excerpt': rawExcerpt,
        'redacted_text': redactedText,
        'private_mode': dbBoolInt(privateMode),
        'created_at': createdAt.toIso8601String(),
      };

  static CapturedMomentRecord fromRow(Map<String, Object?> row) {
    return CapturedMomentRecord(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      sourceSurface: row['source_surface'] as String? ?? '',
      sourceType: row['source_type'] as String? ?? 'text',
      rawExcerpt: row['raw_excerpt'] as String? ?? '',
      redactedText: row['redacted_text'] as String? ?? '',
      privateMode: dbBool(row['private_mode']),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class RiskAnalysisRecord {
  const RiskAnalysisRecord({
    required this.id,
    this.momentId,
    required this.userId,
    required this.verdict,
    this.riskScore = 0,
    this.headline = '',
    this.whyItMatters = '',
    this.facts = const [],
    this.redFlags = const [],
    this.assumptions = const [],
    this.missingInfo = const [],
    this.whatCouldMakeWrong = '',
    this.verificationSteps = const [],
    this.confidence = 0,
    this.edgeSummary = '',
    this.cloudUsed = false,
    required this.createdAt,
  });

  final String id;
  final String? momentId;
  final String userId;
  final String verdict;
  final double riskScore;
  final String headline;
  final String whyItMatters;
  final List<String> facts;
  final List<String> redFlags;
  final List<String> assumptions;
  final List<String> missingInfo;
  final String whatCouldMakeWrong;
  final List<String> verificationSteps;
  final double confidence;
  final String edgeSummary;
  final bool cloudUsed;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'moment_id': momentId,
        'user_id': userId,
        'verdict': verdict,
        'risk_score': riskScore,
        'headline': headline,
        'why_it_matters': whyItMatters,
        'facts': encodeStringList(facts),
        'red_flags': encodeStringList(redFlags),
        'assumptions': encodeStringList(assumptions),
        'missing_info': encodeStringList(missingInfo),
        'what_could_make_wrong': whatCouldMakeWrong,
        'verification_steps': encodeStringList(verificationSteps),
        'confidence': confidence,
        'edge_summary': edgeSummary,
        'cloud_used': dbBoolInt(cloudUsed),
        'created_at': createdAt.toIso8601String(),
      };

  static RiskAnalysisRecord fromRow(Map<String, Object?> row) {
    return RiskAnalysisRecord(
      id: row['id'] as String? ?? '',
      momentId: row['moment_id'] as String?,
      userId: row['user_id'] as String? ?? '',
      verdict: row['verdict'] as String? ?? '',
      riskScore: (row['risk_score'] as num?)?.toDouble() ?? 0,
      headline: row['headline'] as String? ?? '',
      whyItMatters: row['why_it_matters'] as String? ?? '',
      facts: decodeStringList(row['facts']),
      redFlags: decodeStringList(row['red_flags']),
      assumptions: decodeStringList(row['assumptions']),
      missingInfo: decodeStringList(row['missing_info']),
      whatCouldMakeWrong: row['what_could_make_wrong'] as String? ?? '',
      verificationSteps: decodeStringList(row['verification_steps']),
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
      edgeSummary: row['edge_summary'] as String? ?? '',
      cloudUsed: dbBool(row['cloud_used']),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AlterActionRecord {
  const AlterActionRecord({
    required this.id,
    this.momentId,
    required this.userId,
    required this.actionType,
    required this.title,
    this.detail = '',
    this.requiresConfirmation = true,
    this.irreversible = false,
    this.status = 'proposed',
    this.actionPayload = const {},
    this.policyTier = 'safe',
    this.executedResult = '',
    required this.createdAt,
  });

  final String id;
  final String? momentId;
  final String userId;
  final String actionType;
  final String title;
  final String detail;
  final bool requiresConfirmation;
  final bool irreversible;
  final String status;
  final Map<String, dynamic> actionPayload;
  final String policyTier;
  final String executedResult;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'moment_id': momentId,
        'user_id': userId,
        'action_type': actionType,
        'title': title,
        'detail': detail,
        'requires_confirmation': dbBoolInt(requiresConfirmation),
        'irreversible': dbBoolInt(irreversible),
        'status': status,
        'action_payload': encodeJsonMap(actionPayload),
        'policy_tier': policyTier,
        'executed_result': executedResult,
        'created_at': createdAt.toIso8601String(),
      };

  static AlterActionRecord fromRow(Map<String, Object?> row) {
    return AlterActionRecord(
      id: row['id'] as String? ?? '',
      momentId: row['moment_id'] as String?,
      userId: row['user_id'] as String? ?? '',
      actionType: row['action_type'] as String? ?? '',
      title: row['title'] as String? ?? '',
      detail: row['detail'] as String? ?? '',
      requiresConfirmation: dbBool(row['requires_confirmation']),
      irreversible: dbBool(row['irreversible']),
      status: row['status'] as String? ?? 'proposed',
      actionPayload: decodeJsonMap(row['action_payload']),
      policyTier: row['policy_tier'] as String? ?? 'safe',
      executedResult: row['executed_result'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ActionOutcomeRecord {
  const ActionOutcomeRecord({
    required this.id,
    this.actionId,
    this.momentId,
    required this.userId,
    required this.outcome,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String? actionId;
  final String? momentId;
  final String userId;
  final String outcome;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'action_id': actionId,
        'moment_id': momentId,
        'user_id': userId,
        'outcome': outcome,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  static ActionOutcomeRecord fromRow(Map<String, Object?> row) {
    return ActionOutcomeRecord(
      id: row['id'] as String? ?? '',
      actionId: row['action_id'] as String?,
      momentId: row['moment_id'] as String?,
      userId: row['user_id'] as String? ?? '',
      outcome: row['outcome'] as String? ?? '',
      note: row['note'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AuditEventRecord {
  const AuditEventRecord({
    required this.id,
    required this.userId,
    this.momentId,
    required this.kind,
    this.detail = '',
    this.edgeState = 'edge',
    this.metadata = const {},
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? momentId;
  final String kind;
  final String detail;
  final String edgeState;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'user_id': userId,
        'moment_id': momentId,
        'kind': kind,
        'detail': detail,
        'edge_state': edgeState,
        'metadata': encodeJsonMap(metadata),
        'created_at': createdAt.toIso8601String(),
      };

  static AuditEventRecord fromRow(Map<String, Object?> row) {
    return AuditEventRecord(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      momentId: row['moment_id'] as String?,
      kind: row['kind'] as String? ?? '',
      detail: row['detail'] as String? ?? '',
      edgeState: row['edge_state'] as String? ?? 'edge',
      metadata: decodeJsonMap(row['metadata']),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TrustedEntityRecord {
  const TrustedEntityRecord({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.value,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String entityType;
  final String value;
  final DateTime createdAt;

  TrustedEntity toEntity() => TrustedEntity(id: id, type: entityType, value: value);

  Map<String, Object?> toRow() => {
        'id': id,
        'user_id': userId,
        'entity_type': entityType,
        'value': value,
        'created_at': createdAt.toIso8601String(),
      };

  static TrustedEntityRecord fromRow(Map<String, Object?> row) {
    return TrustedEntityRecord(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      entityType: row['entity_type'] as String? ?? 'domain',
      value: row['value'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ContextOsPreferencesRecord {
  const ContextOsPreferencesRecord({
    required this.userId,
    this.privateModeDefault = false,
    this.cloudConsent = true,
    this.enabledSurfaces = const [
      'notification',
      'share_sheet',
      'camera',
      'mic',
      'qr',
      'install',
      'manual',
    ],
    required this.updatedAt,
  });

  final String userId;
  final bool privateModeDefault;
  final bool cloudConsent;
  final List<String> enabledSurfaces;
  final DateTime updatedAt;

  ContextOsPrefs toPrefs() => ContextOsPrefs(
        privateModeDefault: privateModeDefault,
        cloudConsent: cloudConsent,
        enabledSurfaces: enabledSurfaces.toSet(),
      );

  Map<String, Object?> toRow() => {
        'user_id': userId,
        'private_mode_default': dbBoolInt(privateModeDefault),
        'cloud_consent': dbBoolInt(cloudConsent),
        'enabled_surfaces': encodeStringList(enabledSurfaces),
        'updated_at': updatedAt.toIso8601String(),
      };

  static ContextOsPreferencesRecord fromRow(Map<String, Object?> row) {
    return ContextOsPreferencesRecord(
      userId: row['user_id'] as String? ?? '',
      privateModeDefault: dbBool(row['private_mode_default']),
      cloudConsent: dbBool(row['cloud_consent']),
      enabledSurfaces: decodeStringList(row['enabled_surfaces']),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DigitalTwinSourceRecord {
  const DigitalTwinSourceRecord({
    required this.userId,
    required this.sourceKey,
    this.accessLevel = 'off',
    this.connected = false,
    required this.updatedAt,
  });

  final String userId;
  final String sourceKey;
  final String accessLevel;
  final bool connected;
  final DateTime updatedAt;

  TwinSourceConsent toConsent() => TwinSourceConsent(
        source: DigitalTwinSource.fromId(sourceKey),
        accessLevel: TwinAccessLevel.fromId(accessLevel),
        connected: connected,
      );

  Map<String, Object?> toRow() => {
        'user_id': userId,
        'source_key': sourceKey,
        'access_level': accessLevel,
        'connected': dbBoolInt(connected),
        'updated_at': updatedAt.toIso8601String(),
      };

  static DigitalTwinSourceRecord fromRow(Map<String, Object?> row) {
    return DigitalTwinSourceRecord(
      userId: row['user_id'] as String? ?? '',
      sourceKey: row['source_key'] as String? ?? '',
      accessLevel: row['access_level'] as String? ?? 'off',
      connected: dbBool(row['connected']),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DigitalTwinSettingsRecord {
  const DigitalTwinSettingsRecord({
    required this.userId,
    this.autonomyLevel = 'recommend',
    required this.updatedAt,
  });

  final String userId;
  final String autonomyLevel;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
        'user_id': userId,
        'autonomy_level': autonomyLevel,
        'updated_at': updatedAt.toIso8601String(),
      };

  static DigitalTwinSettingsRecord fromRow(Map<String, Object?> row) {
    return DigitalTwinSettingsRecord(
      userId: row['user_id'] as String? ?? '',
      autonomyLevel: row['autonomy_level'] as String? ?? 'recommend',
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ContextOsDao {
  ContextOsDao(this._db);

  final AlterDatabase _db;
  static const _uuid = Uuid();

  // --- captured_moments ---

  Future<List<CapturedMomentRecord>> listCapturedMoments(String userId) async {
    final rows = await _db.db.query(
      'captured_moments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CapturedMomentRecord.fromRow).toList();
  }

  Future<CapturedMomentRecord?> getCapturedMoment(String id) async {
    final rows = await _db.db.query(
      'captured_moments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CapturedMomentRecord.fromRow(rows.first);
  }

  Future<CapturedMomentRecord> insertCapturedMoment(
    CapturedMomentRecord record,
  ) async {
    final saved = _withId(record);
    await _db.db.insert('captured_moments', saved.toRow());
    return saved;
  }

  Future<void> updateCapturedMoment(CapturedMomentRecord record) async {
    await _db.db.update(
      'captured_moments',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteCapturedMoment(String id) async {
    await _db.db.delete(
      'captured_moments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- risk_analyses ---

  Future<List<RiskAnalysisRecord>> listRiskAnalyses(String userId) async {
    final rows = await _db.db.query(
      'risk_analyses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(RiskAnalysisRecord.fromRow).toList();
  }

  Future<RiskAnalysisRecord?> getRiskAnalysis(String id) async {
    final rows = await _db.db.query(
      'risk_analyses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RiskAnalysisRecord.fromRow(rows.first);
  }

  Future<RiskAnalysisRecord> insertRiskAnalysis(RiskAnalysisRecord record) async {
    final id = _idOrNew(record.id);
    final saved = RiskAnalysisRecord(
      id: id,
      momentId: record.momentId,
      userId: record.userId,
      verdict: record.verdict,
      riskScore: record.riskScore,
      headline: record.headline,
      whyItMatters: record.whyItMatters,
      facts: record.facts,
      redFlags: record.redFlags,
      assumptions: record.assumptions,
      missingInfo: record.missingInfo,
      whatCouldMakeWrong: record.whatCouldMakeWrong,
      verificationSteps: record.verificationSteps,
      confidence: record.confidence,
      edgeSummary: record.edgeSummary,
      cloudUsed: record.cloudUsed,
      createdAt: record.createdAt,
    );
    await _db.db.insert('risk_analyses', saved.toRow());
    return saved;
  }

  Future<void> updateRiskAnalysis(RiskAnalysisRecord record) async {
    await _db.db.update(
      'risk_analyses',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteRiskAnalysis(String id) async {
    await _db.db.delete('risk_analyses', where: 'id = ?', whereArgs: [id]);
  }

  // --- alter_actions ---

  Future<List<AlterActionRecord>> listAlterActions(String userId) async {
    final rows = await _db.db.query(
      'alter_actions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AlterActionRecord.fromRow).toList();
  }

  Future<AlterActionRecord?> getAlterAction(String id) async {
    final rows = await _db.db.query(
      'alter_actions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AlterActionRecord.fromRow(rows.first);
  }

  Future<AlterActionRecord> insertAlterAction(AlterActionRecord record) async {
    final id = _idOrNew(record.id);
    final saved = AlterActionRecord(
      id: id,
      momentId: record.momentId,
      userId: record.userId,
      actionType: record.actionType,
      title: record.title,
      detail: record.detail,
      requiresConfirmation: record.requiresConfirmation,
      irreversible: record.irreversible,
      status: record.status,
      actionPayload: record.actionPayload,
      policyTier: record.policyTier,
      executedResult: record.executedResult,
      createdAt: record.createdAt,
    );
    await _db.db.insert('alter_actions', saved.toRow());
    return saved;
  }

  Future<void> updateAlterAction(AlterActionRecord record) async {
    await _db.db.update(
      'alter_actions',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteAlterAction(String id) async {
    await _db.db.delete('alter_actions', where: 'id = ?', whereArgs: [id]);
  }

  // --- action_outcomes ---

  Future<List<ActionOutcomeRecord>> listActionOutcomes(String userId) async {
    final rows = await _db.db.query(
      'action_outcomes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ActionOutcomeRecord.fromRow).toList();
  }

  Future<ActionOutcomeRecord?> getActionOutcome(String id) async {
    final rows = await _db.db.query(
      'action_outcomes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ActionOutcomeRecord.fromRow(rows.first);
  }

  Future<ActionOutcomeRecord> insertActionOutcome(
    ActionOutcomeRecord record,
  ) async {
    final id = _idOrNew(record.id);
    final saved = ActionOutcomeRecord(
      id: id,
      actionId: record.actionId,
      momentId: record.momentId,
      userId: record.userId,
      outcome: record.outcome,
      note: record.note,
      createdAt: record.createdAt,
    );
    await _db.db.insert('action_outcomes', saved.toRow());
    return saved;
  }

  Future<void> updateActionOutcome(ActionOutcomeRecord record) async {
    await _db.db.update(
      'action_outcomes',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteActionOutcome(String id) async {
    await _db.db.delete('action_outcomes', where: 'id = ?', whereArgs: [id]);
  }

  // --- audit_events ---

  Future<List<AuditEventRecord>> listAuditEvents(String userId) async {
    final rows = await _db.db.query(
      'audit_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AuditEventRecord.fromRow).toList();
  }

  Future<AuditEventRecord?> getAuditEvent(String id) async {
    final rows = await _db.db.query(
      'audit_events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AuditEventRecord.fromRow(rows.first);
  }

  Future<AuditEventRecord> insertAuditEvent(AuditEventRecord record) async {
    final id = _idOrNew(record.id);
    final saved = AuditEventRecord(
      id: id,
      userId: record.userId,
      momentId: record.momentId,
      kind: record.kind,
      detail: record.detail,
      edgeState: record.edgeState,
      metadata: record.metadata,
      createdAt: record.createdAt,
    );
    await _db.db.insert('audit_events', saved.toRow());
    return saved;
  }

  Future<void> updateAuditEvent(AuditEventRecord record) async {
    await _db.db.update(
      'audit_events',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteAuditEvent(String id) async {
    await _db.db.delete('audit_events', where: 'id = ?', whereArgs: [id]);
  }

  // --- trusted_entities ---

  Future<List<TrustedEntityRecord>> listTrustedEntities(String userId) async {
    final rows = await _db.db.query(
      'trusted_entities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(TrustedEntityRecord.fromRow).toList();
  }

  Future<TrustedEntityRecord?> getTrustedEntity(String id) async {
    final rows = await _db.db.query(
      'trusted_entities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TrustedEntityRecord.fromRow(rows.first);
  }

  Future<TrustedEntityRecord> insertTrustedEntity(
    TrustedEntityRecord record,
  ) async {
    final id = _idOrNew(record.id);
    final saved = TrustedEntityRecord(
      id: id,
      userId: record.userId,
      entityType: record.entityType,
      value: record.value,
      createdAt: record.createdAt,
    );
    await _db.db.insert('trusted_entities', saved.toRow());
    return saved;
  }

  Future<void> updateTrustedEntity(TrustedEntityRecord record) async {
    await _db.db.update(
      'trusted_entities',
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteTrustedEntity(String id) async {
    await _db.db.delete('trusted_entities', where: 'id = ?', whereArgs: [id]);
  }

  // --- contextos_preferences ---

  Future<ContextOsPreferencesRecord?> getContextOsPreferences(String userId) async {
    final rows = await _db.db.query(
      'contextos_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ContextOsPreferencesRecord.fromRow(rows.first);
  }

  Future<void> upsertContextOsPreferences(ContextOsPreferencesRecord record) async {
    await _db.db.insert(
      'contextos_preferences',
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteContextOsPreferences(String userId) async {
    await _db.db.delete(
      'contextos_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // --- digital_twin_sources ---

  Future<List<DigitalTwinSourceRecord>> listDigitalTwinSources(
    String userId,
  ) async {
    final rows = await _db.db.query(
      'digital_twin_sources',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map(DigitalTwinSourceRecord.fromRow).toList();
  }

  Future<DigitalTwinSourceRecord?> getDigitalTwinSource(
    String userId,
    String sourceKey,
  ) async {
    final rows = await _db.db.query(
      'digital_twin_sources',
      where: 'user_id = ? AND source_key = ?',
      whereArgs: [userId, sourceKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DigitalTwinSourceRecord.fromRow(rows.first);
  }

  Future<void> upsertDigitalTwinSource(DigitalTwinSourceRecord record) async {
    await _db.db.insert(
      'digital_twin_sources',
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDigitalTwinSource(String userId, String sourceKey) async {
    await _db.db.delete(
      'digital_twin_sources',
      where: 'user_id = ? AND source_key = ?',
      whereArgs: [userId, sourceKey],
    );
  }

  // --- digital_twin_settings ---

  Future<DigitalTwinSettingsRecord?> getDigitalTwinSettings(String userId) async {
    final rows = await _db.db.query(
      'digital_twin_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DigitalTwinSettingsRecord.fromRow(rows.first);
  }

  Future<void> upsertDigitalTwinSettings(DigitalTwinSettingsRecord record) async {
    await _db.db.insert(
      'digital_twin_settings',
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDigitalTwinSettings(String userId) async {
    await _db.db.delete(
      'digital_twin_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  CapturedMomentRecord _withId(CapturedMomentRecord record) {
    if (record.id.isNotEmpty) return record;
    return CapturedMomentRecord(
      id: _uuid.v4(),
      userId: record.userId,
      sourceSurface: record.sourceSurface,
      sourceType: record.sourceType,
      rawExcerpt: record.rawExcerpt,
      redactedText: record.redactedText,
      privateMode: record.privateMode,
      createdAt: record.createdAt,
    );
  }

  String _idOrNew(String id) => id.isNotEmpty ? id : _uuid.v4();
}

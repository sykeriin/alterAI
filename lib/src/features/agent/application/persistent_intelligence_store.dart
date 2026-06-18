import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_blob_store.dart';
import '../../profile/application/profile_provider.dart';

final persistentIntelligenceStoreProvider =
    AsyncNotifierProvider<PersistentIntelligenceStore, IntelligenceStoreState>(
      PersistentIntelligenceStore.new,
    );

const _storePrefKey = 'alter.intelligence_store.v1';

class IntelligenceStoreState {
  const IntelligenceStoreState({
    this.audit = const [],
    this.memories = const [],
    this.consent = const [],
    this.exports = const [],
  });

  factory IntelligenceStoreState.fromJson(Map<String, dynamic> json) {
    return IntelligenceStoreState(
      audit: _list(json['audit']).map(IntelligenceAuditEvent.fromJson).toList(),
      memories: _list(json['memories']).map(TwinMemoryRecord.fromJson).toList(),
      consent: _list(json['consent']).map(ConsentRecord.fromJson).toList(),
      exports: _list(json['exports']).map(PrivacyEvent.fromJson).toList(),
    );
  }

  final List<IntelligenceAuditEvent> audit;
  final List<TwinMemoryRecord> memories;
  final List<ConsentRecord> consent;
  final List<PrivacyEvent> exports;

  Map<String, dynamic> toJson() => {
    'audit': audit.map((entry) => entry.toJson()).toList(),
    'memories': memories.map((memory) => memory.toJson()).toList(),
    'consent': consent.map((record) => record.toJson()).toList(),
    'exports': exports.map((event) => event.toJson()).toList(),
  };

  IntelligenceStoreState copyWith({
    List<IntelligenceAuditEvent>? audit,
    List<TwinMemoryRecord>? memories,
    List<ConsentRecord>? consent,
    List<PrivacyEvent>? exports,
  }) {
    return IntelligenceStoreState(
      audit: audit ?? this.audit,
      memories: memories ?? this.memories,
      consent: consent ?? this.consent,
      exports: exports ?? this.exports,
    );
  }

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class IntelligenceAuditEvent {
  const IntelligenceAuditEvent({
    required this.kind,
    required this.summary,
    required this.status,
    required this.at,
    this.metadata = const {},
  });

  factory IntelligenceAuditEvent.fromJson(Map<String, dynamic> json) {
    return IntelligenceAuditEvent(
      kind: _string(json['kind']),
      summary: _string(json['summary']),
      status: _string(json['status'], fallback: 'ok'),
      at: DateTime.tryParse(_string(json['at'])) ?? DateTime.now(),
      metadata: Map<String, Object?>.from(
        json['metadata'] as Map? ?? const <String, Object?>{},
      ),
    );
  }

  final String kind;
  final String summary;
  final String status;
  final DateTime at;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'summary': summary,
    'status': status,
    'at': at.toIso8601String(),
    'metadata': metadata,
  };
}

class TwinMemoryRecord {
  const TwinMemoryRecord({
    required this.source,
    required this.title,
    required this.summary,
    required this.at,
    this.metadata = const {},
    this.embedding,
  });

  factory TwinMemoryRecord.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'];
    return TwinMemoryRecord(
      source: _string(json['source']),
      title: _string(json['title']),
      summary: _string(json['summary']),
      at: DateTime.tryParse(_string(json['at'])) ?? DateTime.now(),
      metadata: Map<String, Object?>.from(
        json['metadata'] as Map? ?? const <String, Object?>{},
      ),
      embedding: rawEmbedding is List
          ? rawEmbedding
              .map((e) => (e as num).toDouble())
              .toList(growable: false)
          : null,
    );
  }

  final String source;
  final String title;
  final String summary;
  final DateTime at;
  final Map<String, Object?> metadata;

  /// Cached semantic-search vector (text-embedding-3-small). Null until the
  /// record has been embedded; persisted so it is computed at most once.
  final List<double>? embedding;

  TwinMemoryRecord copyWith({List<double>? embedding}) => TwinMemoryRecord(
    source: source,
    title: title,
    summary: summary,
    at: at,
    metadata: metadata,
    embedding: embedding ?? this.embedding,
  );

  Map<String, dynamic> toJson() => {
    'source': source,
    'title': title,
    'summary': summary,
    'at': at.toIso8601String(),
    'metadata': metadata,
    if (embedding != null) 'embedding': embedding,
  };
}

class ConsentRecord {
  const ConsentRecord({
    required this.source,
    required this.accessLevel,
    required this.granted,
    required this.at,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      source: _string(json['source']),
      accessLevel: _string(json['access_level'], fallback: 'metadata'),
      granted: json['granted'] == true,
      at: DateTime.tryParse(_string(json['at'])) ?? DateTime.now(),
    );
  }

  final String source;
  final String accessLevel;
  final bool granted;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'source': source,
    'access_level': accessLevel,
    'granted': granted,
    'at': at.toIso8601String(),
  };
}

class PrivacyEvent {
  const PrivacyEvent({
    required this.kind,
    required this.detail,
    required this.at,
  });

  factory PrivacyEvent.fromJson(Map<String, dynamic> json) {
    return PrivacyEvent(
      kind: _string(json['kind']),
      detail: _string(json['detail']),
      at: DateTime.tryParse(_string(json['at'])) ?? DateTime.now(),
    );
  }

  final String kind;
  final String detail;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'detail': detail,
    'at': at.toIso8601String(),
  };
}

class PersistentIntelligenceStore
    extends AsyncNotifier<IntelligenceStoreState> {
  SecureBlobStore? _blob;

  /// Set when the memory set changes so the on-device vector index is rebuilt.
  bool _vectorDirty = true;

  /// Lazily-created encrypted local store (key in the platform keystore).
  Future<SecureBlobStore> _store() async =>
      _blob ??= await EncryptedBlobStore.create();

  @override
  Future<IntelligenceStoreState> build() async {
    final raw = await (await _store()).read(_storePrefKey);
    if (raw == null || raw.isEmpty) return const IntelligenceStoreState();
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return IntelligenceStoreState.fromJson(json);
      }
    } catch (_) {}
    return const IntelligenceStoreState();
  }

  Future<void> recordAudit({
    required String kind,
    required String summary,
    String status = 'ok',
    Map<String, Object?> metadata = const {},
  }) async {
    final current = await future;
    await _save(
      current.copyWith(
        audit: [
          IntelligenceAuditEvent(
            kind: kind,
            summary: _redact(summary),
            status: status,
            at: DateTime.now(),
            metadata: metadata,
          ),
          ...current.audit,
        ].take(300).toList(growable: false),
      ),
    );
  }

  Future<void> addMemory({
    required String source,
    required String title,
    required String summary,
    Map<String, Object?> metadata = const {},
  }) async {
    final current = await future;
    await _save(
      current.copyWith(
        memories: [
          TwinMemoryRecord(
            source: source,
            title: _redact(title),
            summary: _redact(summary),
            at: DateTime.now(),
            metadata: metadata,
          ),
          ...current.memories,
        ].take(500).toList(growable: false),
      ),
    );
    _vectorDirty = true;
  }

  Future<List<TwinMemoryRecord>> searchMemory(String query) async {
    final current = await future;
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return current.memories.take(20).toList(growable: false);

    // Prefer semantic recall (embeddings) when cloud AI is available.
    final ranked = await _semanticSearch(query, current);
    if (ranked != null) return ranked;

    // Fallback: case-insensitive substring match.
    return current.memories
        .where(
          (memory) =>
              memory.title.toLowerCase().contains(q) ||
              memory.summary.toLowerCase().contains(q) ||
              memory.source.toLowerCase().contains(q),
        )
        .take(20)
        .toList(growable: false);
  }

  /// Embedding-based recall. Returns null when embeddings are unavailable so the
  /// caller falls back to keyword search. Lazily embeds the query plus any
  /// memories that don't yet have a vector (one batched call), persists those
  /// vectors, then ranks every memory by cosine similarity to the query.
  Future<List<TwinMemoryRecord>?> _semanticSearch(
    String query,
    IntelligenceStoreState current,
  ) async {
    final memories = current.memories;
    if (memories.isEmpty) return const [];
    final openai = ref.read(openAIServiceProvider);
    if (openai == null) return null;

    final missing = <int>[];
    for (var i = 0; i < memories.length; i++) {
      final emb = memories[i].embedding;
      if (emb == null || emb.isEmpty) missing.add(i);
    }
    // Cap how many we embed per call so a huge backlog doesn't blow the limit.
    final toEmbed = missing.take(95).toList();
    final inputs = <String>[
      query,
      for (final i in toEmbed) '${memories[i].title}. ${memories[i].summary}'.trim(),
    ];
    final vectors = await openai.embed(inputs);
    if (vectors.length != inputs.length) return null;
    final queryVec = vectors.first;

    var working = memories;
    if (toEmbed.isNotEmpty) {
      final updated = List<TwinMemoryRecord>.from(memories);
      for (var k = 0; k < toEmbed.length; k++) {
        updated[toEmbed[k]] =
            updated[toEmbed[k]].copyWith(embedding: vectors[k + 1]);
      }
      working = updated;
      await _save(current.copyWith(memories: updated));
      _vectorDirty = true;
    }

    // Portable in-Dart cosine ranking (SQLCipher embeddings when available).
    final scored = <MapEntry<double, TwinMemoryRecord>>[];
    for (final m in working) {
      final v = m.embedding;
      if (v == null || v.length != queryVec.length) continue;
      scored.add(MapEntry(_cosine(queryVec, v), m));
    }
    if (scored.isEmpty) return null;
    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.take(20).map((e) => e.value).toList(growable: false);
  }

  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  /// Stable, non-reversible key (FNV-1a) for mapping a vector hit back to its
  /// (encrypted) memory record without storing the text in the vector index.
  String _refKey(TwinMemoryRecord m) {
    var hash = 0xcbf29ce484222325;
    for (final code in '${m.source}|${m.title}'.codeUnits) {
      hash = (hash ^ code) * 0x100000001b3;
    }
    return (hash & 0x7fffffffffffffff).toRadixString(16);
  }

  Future<void> recordConsent({
    required String source,
    required String accessLevel,
    required bool granted,
  }) async {
    final current = await future;
    await _save(
      current.copyWith(
        consent: [
          ConsentRecord(
            source: source,
            accessLevel: accessLevel,
            granted: granted,
            at: DateTime.now(),
          ),
          ...current.consent,
        ].take(120).toList(growable: false),
      ),
    );
  }

  Future<String> exportData() async {
    final current = await future;
    await _save(
      current.copyWith(
        exports: [
          PrivacyEvent(
            kind: 'export',
            detail: 'Local intelligence export generated.',
            at: DateTime.now(),
          ),
          ...current.exports,
        ],
      ),
    );
    return (await future).exportJson();
  }

  Future<void> deleteScopes(List<String> scopes) async {
    final current = await future;
    final normalized = scopes.map((scope) => scope.toLowerCase()).toSet();
    await _save(
      current.copyWith(
        audit: normalized.contains('audit') ? const [] : current.audit,
        memories: normalized.contains('memories') ? const [] : current.memories,
        consent: normalized.contains('consent') ? const [] : current.consent,
        exports: [
          PrivacyEvent(
            kind: 'delete',
            detail: 'Deleted scopes: ${normalized.join(', ')}',
            at: DateTime.now(),
          ),
          ...current.exports,
        ],
      ),
    );
    if (normalized.contains('memories')) _vectorDirty = true;
  }

  Future<void> _save(IntelligenceStoreState next) async {
    state = AsyncValue.data(next);
    await (await _store()).write(_storePrefKey, jsonEncode(next.toJson()));
  }
}

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _string(Object? raw, {String fallback = ''}) {
  return raw is String && raw.isNotEmpty ? raw : fallback;
}

String _redact(String text) {
  return text
      .replaceAll(RegExp(r'\b\d{4,}\b'), '[number]')
      .replaceAll(RegExp(r'\b[\w.+-]+@[\w.-]+\.\w+\b'), '[email]')
      .replaceAll(
        RegExp(
          r'\b(otp|password|passcode|pin|cvv)\s*[:=]?\s*\S+',
          caseSensitive: false,
        ),
        '[secret]',
      );
}

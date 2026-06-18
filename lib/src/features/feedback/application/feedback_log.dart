import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_blob_store.dart';
import '../domain/feedback_event.dart';

final feedbackLogProvider =
    AsyncNotifierProvider<FeedbackLog, List<FeedbackEvent>>(FeedbackLog.new);

/// Local-first, encrypted log of explicit decision feedback. Structured events
/// kept here power retrieval and future preference scoring; the agent also
/// mirrors a human-readable summary into twin memory when it records feedback.
class FeedbackLog extends AsyncNotifier<List<FeedbackEvent>> {
  static const _key = 'alter.feedback.log.v1';

  SecureBlobStore? _blob;
  Future<SecureBlobStore> _store() async =>
      _blob ??= await EncryptedBlobStore.create();

  @override
  Future<List<FeedbackEvent>> build() async {
    final raw = await (await _store()).read(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => FeedbackEvent.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> record(FeedbackEvent event) async {
    final current = await future;
    final next = [event, ...current].take(500).toList(growable: false);
    state = AsyncValue.data(next);
    await (await _store()).write(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}

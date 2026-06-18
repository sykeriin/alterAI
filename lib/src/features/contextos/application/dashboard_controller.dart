import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/contextos_models.dart';

/// One entry in the proof ledger / live-moments feed.
class LedgerEntry {
  const LedgerEntry({
    required this.headline,
    required this.verdict,
    required this.confidence,
    required this.cloudUsed,
    required this.timeLabel,
  });

  final String headline;
  final RiskVerdict verdict;
  final double confidence;
  final bool cloudUsed;
  final String timeLabel;
}

class AuditEntry {
  const AuditEntry({
    required this.kind,
    required this.detail,
    required this.edgeState,
    required this.timeLabel,
  });

  final String kind;
  final String detail;
  final String edgeState;
  final String timeLabel;
}

class DashboardData {
  const DashboardData({
    required this.ledger,
    required this.riskMap,
    required this.audit,
    required this.momentCount,
    required this.persisted,
  });

  final List<LedgerEntry> ledger;
  final Map<RiskVerdict, int> riskMap;
  final List<AuditEntry> audit;
  final int momentCount;

  /// False when Supabase returned nothing (migration not applied / no session) —
  /// the dashboard then honestly shows it is running on live in-memory state only.
  final bool persisted;

  static const empty = DashboardData(
    ledger: [],
    riskMap: {},
    audit: [],
    momentCount: 0,
    persisted: false,
  );
}

final contextDashboardProvider =
    AsyncNotifierProvider<ContextDashboardController, DashboardData>(
      ContextDashboardController.new,
    );

class ContextDashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() => _load();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _load());
  }

  Future<DashboardData> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return DashboardData.empty;

    var persisted = false;
    final ledger = <LedgerEntry>[];
    final riskMap = <RiskVerdict, int>{};
    final audit = <AuditEntry>[];
    var momentCount = 0;

    try {
      final rows =
          (await client
                      .from('risk_analyses')
                      .select(
                        'verdict, headline, confidence, cloud_used, created_at',
                      )
                      .eq('user_id', userId)
                      .order('created_at', ascending: false)
                      .limit(40)
                  as List)
              .cast<Map<String, dynamic>>();
      persisted = true;
      for (final r in rows) {
        final v = RiskVerdict.fromId((r['verdict'] ?? '').toString());
        riskMap[v] = (riskMap[v] ?? 0) + 1;
        ledger.add(
          LedgerEntry(
            headline: (r['headline'] ?? 'Moment').toString(),
            verdict: v,
            confidence: _d(r['confidence']),
            cloudUsed: r['cloud_used'] == true,
            timeLabel: _time(r['created_at']),
          ),
        );
      }
    } catch (_) {}

    try {
      final rows =
          (await client
                      .from('audit_events')
                      .select('kind, detail, edge_state, created_at')
                      .eq('user_id', userId)
                      .order('created_at', ascending: false)
                      .limit(30)
                  as List)
              .cast<Map<String, dynamic>>();
      persisted = true;
      for (final r in rows) {
        audit.add(
          AuditEntry(
            kind: (r['kind'] ?? '').toString(),
            detail: (r['detail'] ?? '').toString(),
            edgeState: (r['edge_state'] ?? 'edge').toString(),
            timeLabel: _time(r['created_at']),
          ),
        );
      }
    } catch (_) {}

    try {
      final rows =
          (await client
                  .from('captured_moments')
                  .select('id')
                  .eq('user_id', userId)
              as List);
      momentCount = rows.length;
      persisted = true;
    } catch (_) {}

    return DashboardData(
      ledger: ledger,
      riskMap: riskMap,
      audit: audit,
      momentCount: momentCount,
      persisted: persisted,
    );
  }

  double _d(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _time(Object? iso) {
    final dt = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

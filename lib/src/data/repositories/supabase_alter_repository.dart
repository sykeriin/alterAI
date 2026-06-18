import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/alter_models.dart';
import '../../domain/repositories/alter_repository.dart';

class SupabaseAlterRepository implements AlterRepository {
  SupabaseAlterRepository(this._client);
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Assistant Brief ───────────────────────────────────────────────────────

  @override
  Future<AssistantBrief> loadAssistantBrief() async {
    final uid = _uid;
    if (uid == null) return AssistantBrief.empty;

    final rows = await _client
        .from('assistant_briefs')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return AssistantBrief.empty;
    }
    final r = rows.first;
    return AssistantBrief(
      greeting: _string(r['greeting']),
      focus: _string(r['focus']),
      nextAction: _string(r['next_action']),
      signals: _stringList(r['signals']),
    );
  }

  // ── Clone Council ─────────────────────────────────────────────────────────

  @override
  Future<List<CloneAgent>> loadCloneCouncil() async {
    final uid = _uid;
    if (uid == null) return const <CloneAgent>[];

    final rows = await _client
        .from('clone_agents')
        .select()
        .eq('user_id', uid)
        .order('created_at');

    if (rows.isEmpty) return const <CloneAgent>[];

    return rows.map((r) {
      return CloneAgent(
        name: _string(r['name']),
        role: _string(r['role']),
        state: _string(r['state'], fallback: 'Ready'),
        confidence: _double(r['confidence']),
        accent: _color(r['accent_hex']),
        summary: _string(r['summary']),
      );
    }).toList();
  }

  // ── Future Scenarios ──────────────────────────────────────────────────────

  @override
  Future<List<FutureScenario>> loadFutureScenarios() async {
    final uid = _uid;
    if (uid == null) return const <FutureScenario>[];

    final rows = await _client
        .from('future_scenarios')
        .select()
        .eq('user_id', uid)
        .order('created_at');

    if (rows.isEmpty) return const <FutureScenario>[];

    return rows.map((r) {
      return FutureScenario(
        title: _string(r['title']),
        horizon: _string(r['horizon']),
        probability: _double(r['probability']),
        upside: _string(r['upside']),
        risk: _string(r['risk']),
        levers: _stringList(r['levers']),
      );
    }).toList();
  }

  // ── Opportunity Signals ───────────────────────────────────────────────────

  @override
  Future<List<OpportunitySignal>> loadOpportunitySignals() async {
    final uid = _uid;
    if (uid == null) return const <OpportunitySignal>[];

    final rows = await _client
        .from('opportunity_signals')
        .select()
        .eq('user_id', uid)
        .order('score', ascending: false);

    if (rows.isEmpty) return const <OpportunitySignal>[];

    return rows.map((r) {
      return OpportunitySignal(
        title: _string(r['title']),
        category: _string(r['category']),
        score: _double(r['score']),
        source: _string(r['source']),
        window: _string(r['time_window']),
        evidence: _string(r['evidence']),
      );
    }).toList();
  }

  // ── Social Graph ──────────────────────────────────────────────────────────

  @override
  Future<List<SocialContact>> loadSocialGraph() async {
    final uid = _uid;
    if (uid == null) return const <SocialContact>[];

    final rows = await _client
        .from('social_contacts')
        .select()
        .eq('user_id', uid)
        .order('strength', ascending: false);

    if (rows.isEmpty) return const <SocialContact>[];

    return rows.map((r) {
      return SocialContact(
        name: _string(r['name']),
        context: _string(r['context']),
        strength: _double(r['strength']),
        tags: _stringList(r['tags']),
      );
    }).toList();
  }

  // ── Reputation Events ─────────────────────────────────────────────────────

  @override
  Future<List<ReputationEvent>> loadReputationEvents() async {
    final uid = _uid;
    if (uid == null) return const <ReputationEvent>[];

    final rows = await _client
        .from('reputation_events')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);

    if (rows.isEmpty) return const <ReputationEvent>[];

    return rows.map((r) {
      return ReputationEvent(
        title: _string(r['title']),
        delta: _int(r['delta']),
        description: _string(r['description']),
        timestamp: _string(r['timestamp']),
      );
    }).toList();
  }

  // ── Lens Insights ─────────────────────────────────────────────────────────

  @override
  Future<List<LensInsight>> loadLensInsights() async {
    final uid = _uid;
    if (uid == null) return const <LensInsight>[];

    final rows = await _client
        .from('lens_insights')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(10);

    if (rows.isEmpty) return const <LensInsight>[];

    return rows.map((r) {
      return LensInsight(
        title: _string(r['title']),
        confidence: _double(r['confidence']),
        description: _string(r['description']),
        actions: _stringList(r['actions']),
      );
    }).toList();
  }
}

String _string(Object? raw, {String fallback = ''}) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

List<String> _stringList(Object? raw) {
  if (raw is Iterable) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(raw);
  return text.isEmpty ? const <String>[] : <String>[text];
}

double _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

int _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

Color _color(Object? raw) {
  final text = _string(raw);
  final parsed = int.tryParse(text);
  return Color(parsed ?? 0xFF7C3AED);
}

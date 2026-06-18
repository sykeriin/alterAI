import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/alter_database.dart';
import '../../core/database/json_column.dart';
import '../../domain/entities/alter_models.dart';

class LifeOsDao {
  LifeOsDao(this._db);

  final AlterDatabase _db;
  static const _uuid = Uuid();

  static const _emptyBrief = AssistantBrief(
    greeting: '',
    focus: '',
    nextAction: '',
    signals: [],
  );

  Future<AssistantBrief> loadAssistantBrief(String userId) async {
    final rows = await _db.db.query(
      'assistant_briefs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return _emptyBrief;
    final r = rows.first;
    return AssistantBrief(
      greeting: r['greeting'] as String? ?? '',
      focus: r['focus'] as String? ?? '',
      nextAction: r['next_action'] as String? ?? '',
      signals: decodeStringList(r['signals']),
    );
  }

  Future<void> saveAssistantBrief(String userId, AssistantBrief brief) async {
    final now = DateTime.now().toIso8601String();
    await _db.db.insert(
      'assistant_briefs',
      {
        'id': _uuid.v4(),
        'user_id': userId,
        'greeting': brief.greeting,
        'focus': brief.focus,
        'next_action': brief.nextAction,
        'signals': encodeStringList(brief.signals),
        'created_at': now,
      },
    );
  }

  Future<List<CloneAgent>> loadCloneCouncil(String userId) async {
    final rows = await _db.db.query(
      'clone_agents',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) {
      final hex = r['accent_hex'] as String? ?? '0xFF00FF00';
      return CloneAgent(
        name: r['name'] as String? ?? '',
        role: r['role'] as String? ?? '',
        state: r['state'] as String? ?? '',
        confidence: (r['confidence'] as num?)?.toDouble() ?? 0,
        accent: Color(int.parse(hex)),
        summary: r['summary'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> replaceCloneCouncil(String userId, List<CloneAgent> agents) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete('clone_agents', where: 'user_id = ?', whereArgs: [userId]);
      for (final agent in agents) {
        await txn.insert('clone_agents', {
          'id': _uuid.v4(),
          'user_id': userId,
          'name': agent.name,
          'role': agent.role,
          'state': agent.state,
          'confidence': agent.confidence,
          'accent_hex': agent.accent.toARGB32().toString(),
          'summary': agent.summary,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<List<FutureScenario>> loadFutureScenarios(String userId) async {
    final rows = await _db.db.query(
      'future_scenarios',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (r) => FutureScenario(
            title: r['title'] as String? ?? '',
            horizon: r['horizon'] as String? ?? '',
            probability: (r['probability'] as num?)?.toDouble() ?? 0,
            upside: r['upside'] as String? ?? '',
            risk: r['risk'] as String? ?? '',
            levers: decodeStringList(r['levers']),
          ),
        )
        .toList();
  }

  Future<void> replaceFutureScenarios(
    String userId,
    List<FutureScenario> scenarios,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete(
        'future_scenarios',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final scenario in scenarios) {
        await txn.insert('future_scenarios', {
          'id': _uuid.v4(),
          'user_id': userId,
          'title': scenario.title,
          'horizon': scenario.horizon,
          'probability': scenario.probability,
          'upside': scenario.upside,
          'risk': scenario.risk,
          'levers': encodeStringList(scenario.levers),
          'created_at': now,
        });
      }
    });
  }

  Future<List<OpportunitySignal>> loadOpportunitySignals(String userId) async {
    final rows = await _db.db.query(
      'opportunity_signals',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'score DESC',
    );
    return rows
        .map(
          (r) => OpportunitySignal(
            title: r['title'] as String? ?? '',
            category: r['category'] as String? ?? '',
            score: (r['score'] as num?)?.toDouble() ?? 0,
            source: r['source'] as String? ?? '',
            window: r['time_window'] as String? ?? '',
            evidence: r['evidence'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> replaceOpportunitySignals(
    String userId,
    List<OpportunitySignal> signals,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete(
        'opportunity_signals',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final signal in signals) {
        await txn.insert('opportunity_signals', {
          'id': _uuid.v4(),
          'user_id': userId,
          'title': signal.title,
          'category': signal.category,
          'score': signal.score,
          'source': signal.source,
          'time_window': signal.window,
          'evidence': signal.evidence,
          'created_at': now,
        });
      }
    });
  }

  Future<List<SocialContact>> loadSocialGraph(String userId) async {
    final rows = await _db.db.query(
      'social_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'strength DESC',
    );
    return rows
        .map(
          (r) => SocialContact(
            name: r['name'] as String? ?? '',
            context: r['context'] as String? ?? '',
            strength: (r['strength'] as num?)?.toDouble() ?? 0,
            tags: decodeStringList(r['tags']),
          ),
        )
        .toList();
  }

  Future<void> replaceSocialGraph(String userId, List<SocialContact> contacts) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete(
        'social_contacts',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final contact in contacts) {
        await txn.insert('social_contacts', {
          'id': _uuid.v4(),
          'user_id': userId,
          'name': contact.name,
          'context': contact.context,
          'strength': contact.strength,
          'tags': encodeStringList(contact.tags),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<List<ReputationEvent>> loadReputationEvents(
    String userId, {
    int limit = 20,
  }) async {
    final rows = await _db.db.query(
      'reputation_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => ReputationEvent(
            title: r['title'] as String? ?? '',
            delta: (r['delta'] as num?)?.toInt() ?? 0,
            description: r['description'] as String? ?? '',
            timestamp: r['timestamp'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> insertReputationEvent(
    String userId,
    ReputationEvent event,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _db.db.insert('reputation_events', {
      'id': _uuid.v4(),
      'user_id': userId,
      'title': event.title,
      'delta': event.delta,
      'description': event.description,
      'timestamp': event.timestamp,
      'created_at': now,
    });
  }

  Future<List<LensInsight>> loadLensInsights(
    String userId, {
    int limit = 10,
  }) async {
    final rows = await _db.db.query(
      'lens_insights',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => LensInsight(
            title: r['title'] as String? ?? '',
            confidence: (r['confidence'] as num?)?.toDouble() ?? 0,
            description: r['description'] as String? ?? '',
            actions: decodeStringList(r['actions']),
          ),
        )
        .toList();
  }

  Future<void> replaceLensInsights(String userId, List<LensInsight> insights) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete('lens_insights', where: 'user_id = ?', whereArgs: [userId]);
      for (final insight in insights) {
        await txn.insert('lens_insights', {
          'id': _uuid.v4(),
          'user_id': userId,
          'title': insight.title,
          'confidence': insight.confidence,
          'description': insight.description,
          'actions': encodeStringList(insight.actions),
          'created_at': now,
        });
      }
    });
  }
}

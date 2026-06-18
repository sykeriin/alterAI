import 'package:flutter/material.dart';

import '../../../core/theme/alter_palette.dart';

// ---------------------------------------------------------------------------
// DayTwin: a living model of today.
// ---------------------------------------------------------------------------

enum DayPathType {
  defaultDay('Default Day', AlterPalette.cyan),
  riskDay('Risk Day', AlterPalette.danger),
  optimizedDay('Optimized Day', AlterPalette.mint);

  const DayPathType(this.label, this.color);
  final String label;
  final Color color;

  static DayPathType fromId(String v) {
    final s = v.toLowerCase();
    if (s.contains('risk')) return DayPathType.riskDay;
    if (s.contains('optim')) return DayPathType.optimizedDay;
    return DayPathType.defaultDay;
  }
}

class DayBlock {
  const DayBlock({
    required this.time,
    required this.title,
    required this.note,
    required this.stress,
  });

  factory DayBlock.fromJson(Map<String, dynamic> j) => DayBlock(
    time: (j['time'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    note: (j['note'] ?? '').toString(),
    stress: _d(j['stress']),
  );

  final String time;
  final String title;
  final String note;
  final double stress; // 0..1
}

class DayPath {
  const DayPath({
    required this.type,
    required this.summary,
    required this.dayScore,
    required this.blocks,
  });

  factory DayPath.fromJson(Map<String, dynamic> j) => DayPath(
    type: DayPathType.fromId((j['type'] ?? '').toString()),
    summary: (j['summary'] ?? '').toString(),
    dayScore: _d(j['day_score']),
    blocks: _list(j['blocks'], DayBlock.fromJson),
  );

  final DayPathType type;
  final String summary;
  final double dayScore; // 0..1
  final List<DayBlock> blocks;
}

class DayTwinResult {
  const DayTwinResult({
    required this.headline,
    required this.pressurePoints,
    required this.paths,
    required this.nextBestMove,
    required this.cloudUsed,
  });

  factory DayTwinResult.fromJson(
    Map<String, dynamic> j, {
    required bool cloud,
  }) => DayTwinResult(
    headline: (j['headline'] ?? 'Your day, modeled').toString(),
    pressurePoints: _strs(j['pressure_points']),
    paths: _list(j['paths'], DayPath.fromJson),
    nextBestMove: (j['next_best_move'] ?? '').toString(),
    cloudUsed: cloud,
  );

  final String headline;
  final List<String> pressurePoints;
  final List<DayPath> paths;
  final String nextBestMove;
  final bool cloudUsed;
}

// ---------------------------------------------------------------------------
// FutureTwin: bigger decisions, three paths.
// ---------------------------------------------------------------------------

enum FuturePathType {
  safe('Safe Path', AlterPalette.mint),
  smart('Smart Path', AlterPalette.cyan),
  bold('Bold Path', AlterPalette.aura);

  const FuturePathType(this.label, this.color);
  final String label;
  final Color color;

  static FuturePathType fromId(String v) {
    final s = v.toLowerCase();
    if (s.contains('bold')) return FuturePathType.bold;
    if (s.contains('smart')) return FuturePathType.smart;
    return FuturePathType.safe;
  }
}

class FuturePath {
  const FuturePath({
    required this.type,
    required this.thesis,
    required this.effort,
    required this.risk,
    required this.upside,
    required this.regret,
    required this.roadmap,
  });

  factory FuturePath.fromJson(Map<String, dynamic> j) => FuturePath(
    type: FuturePathType.fromId((j['type'] ?? '').toString()),
    thesis: (j['thesis'] ?? '').toString(),
    effort: _d(j['effort']),
    risk: _d(j['risk']),
    upside: _d(j['upside']),
    regret: _d(j['regret']),
    roadmap: _strs(j['roadmap']),
  );

  final FuturePathType type;
  final String thesis;
  final double effort; // 0..1
  final double risk; // 0..1
  final double upside; // 0..1
  final double regret; // 0..1
  final List<String> roadmap;
}

class FutureTwinResult {
  const FutureTwinResult({
    required this.headline,
    required this.summary,
    required this.paths,
    required this.recommended,
    required this.regretMinimizer,
    required this.cloudUsed,
  });

  factory FutureTwinResult.fromJson(
    Map<String, dynamic> j, {
    required bool cloud,
  }) => FutureTwinResult(
    headline: (j['headline'] ?? 'Three futures, compared').toString(),
    summary: (j['summary'] ?? '').toString(),
    paths: _list(j['paths'], FuturePath.fromJson),
    recommended: (j['recommended'] ?? '').toString(),
    regretMinimizer: (j['regret_minimizer'] ?? '').toString(),
    cloudUsed: cloud,
  );

  final String headline;
  final String summary;
  final List<FuturePath> paths;
  final String recommended; // safe | smart | bold
  final String regretMinimizer;
  final bool cloudUsed;

  FuturePathType? get recommendedType =>
      recommended.isEmpty ? null : FuturePathType.fromId(recommended);
}

// --- shared json helpers ---
double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strs(Object? v) => v is List
    ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
    : const [];

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => v is List
    ? v
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList()
    : const [];

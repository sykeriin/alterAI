enum MissionSurface { phone, laptop }

class MissionModule {
  const MissionModule({
    required this.id,
    required this.title,
    required this.route,
    required this.surface,
    required this.signal,
    required this.health,
    required this.status,
    required this.cadence,
    required this.capabilities,
  });

  final String id;
  final String title;
  final String route;
  final MissionSurface surface;
  final double signal;
  final double health;
  final String status;
  final String cadence;
  final List<String> capabilities;

  MissionModule copyWith({double? signal, double? health, String? status}) {
    return MissionModule(
      id: id,
      title: title,
      route: route,
      surface: surface,
      signal: signal ?? this.signal,
      health: health ?? this.health,
      status: status ?? this.status,
      cadence: cadence,
      capabilities: capabilities,
    );
  }
}

class MissionMetric {
  const MissionMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.moduleId,
  });

  final String label;
  final String value;
  final String detail;
  final String moduleId;
}

class MissionEvent {
  const MissionEvent({
    required this.time,
    required this.title,
    required this.source,
    required this.impact,
  });

  final String time;
  final String title;
  final String source;
  final String impact;
}

class MissionControlSnapshot {
  const MissionControlSnapshot({
    required this.operatorName,
    required this.activeObjective,
    required this.readiness,
    required this.phoneModules,
    required this.laptopModules,
    required this.metrics,
    required this.events,
    this.backendStatus = 'local',
    this.routeTargets = const <String>[],
    this.degradedServices = const <String>[],
  });

  final String operatorName;
  final String activeObjective;
  final double readiness;
  final List<MissionModule> phoneModules;
  final List<MissionModule> laptopModules;
  final List<MissionMetric> metrics;
  final List<MissionEvent> events;
  final String backendStatus;
  final List<String> routeTargets;
  final List<String> degradedServices;

  int get activeModuleCount => phoneModules.length + laptopModules.length;

  MissionControlSnapshot copyWith({
    String? activeObjective,
    double? readiness,
    List<MissionModule>? phoneModules,
    List<MissionModule>? laptopModules,
    List<MissionMetric>? metrics,
    List<MissionEvent>? events,
    String? backendStatus,
    List<String>? routeTargets,
    List<String>? degradedServices,
  }) {
    return MissionControlSnapshot(
      operatorName: operatorName,
      activeObjective: activeObjective ?? this.activeObjective,
      readiness: readiness ?? this.readiness,
      phoneModules: phoneModules ?? this.phoneModules,
      laptopModules: laptopModules ?? this.laptopModules,
      metrics: metrics ?? this.metrics,
      events: events ?? this.events,
      backendStatus: backendStatus ?? this.backendStatus,
      routeTargets: routeTargets ?? this.routeTargets,
      degradedServices: degradedServices ?? this.degradedServices,
    );
  }
}

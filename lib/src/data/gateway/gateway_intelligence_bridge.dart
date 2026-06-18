import '../../features/contextos/domain/simulations.dart';
import '../../features/mission/data/mission_control_api_client.dart'
    hide FutureTwinResult;
import 'alter_gateway_api_client.dart';

FutureTwinResult futureTwinFromDecision(
  IntelligenceDecisionReport report, {
  required String question,
}) {
  final options = report.futureOptions;
  FuturePathType mapName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bold') || lower.contains('risk')) {
      return FuturePathType.bold;
    }
    if (lower.contains('smart') || lower.contains('balanced')) {
      return FuturePathType.smart;
    }
    return FuturePathType.safe;
  }

  final paths = options.isEmpty
      ? <FuturePath>[]
      : options
          .map(
            (option) => FuturePath(
              type: mapName(option.name),
              thesis: option.thesis,
              effort: (1 - option.successProbability).clamp(0.0, 1.0),
              risk: (option.riskScore / 100).clamp(0.0, 1.0),
              upside: (option.opportunityScore / 100).clamp(0.0, 1.0),
              regret: (option.riskScore / 100).clamp(0.0, 1.0),
              roadmap: report.nextActions.take(3).toList(),
            ),
          )
          .toList(growable: false);

  final recommended = options.isEmpty
      ? ''
      : switch (mapName(options.first.name)) {
          FuturePathType.bold => 'bold',
          FuturePathType.smart => 'smart',
          FuturePathType.safe => 'safe',
        };

  return FutureTwinResult(
    headline: report.recommendation,
    summary: report.decisionSummary,
    paths: paths,
    recommended: recommended,
    regretMinimizer: report.experimentPlan.action.isNotEmpty
        ? report.experimentPlan.action
        : report.recommendedFuture,
    cloudUsed: true,
  );
}

String formatAgentPlan(AgentPlanSnapshot plan) {
  final steps = plan.steps
      .map(
        (step) =>
            '${step.title} (${step.toolName}): ${step.rationale}',
      )
      .join(' | ');
  final warnings = plan.policyWarnings.isEmpty
      ? ''
      : ' Warnings: ${plan.policyWarnings.join('; ')}.';
  return '${plan.goal} — ready=${plan.readyToExecute}. Steps: $steps.$warnings';
}

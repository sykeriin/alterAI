import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../domain/entities/alter_models.dart';
import '../../backend/application/backend_config_controller.dart';
import '../../backend/data/backend_feature_api_client.dart';
import '../../profile/application/profile_provider.dart';
import '../../profile/domain/user_profile.dart';
import '../../shared/application/alter_data_providers.dart';

class FutureSimulatorScreen extends ConsumerStatefulWidget {
  const FutureSimulatorScreen({super.key});

  @override
  ConsumerState<FutureSimulatorScreen> createState() =>
      _FutureSimulatorScreenState();
}

class _FutureSimulatorScreenState extends ConsumerState<FutureSimulatorScreen> {
  double _riskTolerance = 0.62;
  double _timeHorizon = 0.48;
  bool _isSimulating = false;
  String _simError = '';

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(futureScenariosProvider);
    final theme = Theme.of(context);
    final scenarioItems = scenarios.asData?.value ?? const <FutureScenario>[];
    final averageConfidence = scenarioItems.isEmpty
        ? null
        : scenarioItems.fold<double>(0, (sum, item) => sum + item.probability) /
              scenarioItems.length;

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Future Simulator',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Model alternate paths using memory, social graph, opportunities, and council assumptions.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              MetricTile(
                label: 'Scenario runs',
                value: '${scenarioItems.length}',
                icon: LucideIcons.route,
                accent: AlterPalette.iris,
              ),
              MetricTile(
                label: 'Risk setting',
                value: '${(_riskTolerance * 100).round()}%',
                icon: LucideIcons.scale,
                accent: AlterPalette.aura,
              ),
              MetricTile(
                label: 'Time horizon',
                value: '${(_timeHorizon * 60).round()}mo',
                icon: LucideIcons.calendar,
                accent: AlterPalette.cyan,
              ),
              MetricTile(
                label: 'Confidence',
                value: averageConfidence == null
                    ? '--'
                    : '${(averageConfidence * 100).round()}%',
                icon: LucideIcons.shield_check,
                accent: AlterPalette.mint,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Simulation controls',
                  subtitle:
                      'Tune the assumptions then let ALTER generate your futures.',
                ),
                const SizedBox(height: 18),
                _SliderRow(
                  label: 'Risk tolerance',
                  value: _riskTolerance,
                  onChanged: (v) => setState(() => _riskTolerance = v),
                ),
                _SliderRow(
                  label: 'Time horizon',
                  value: _timeHorizon,
                  onChanged: (v) => setState(() => _timeHorizon = v),
                ),
                const SizedBox(height: 14),
                PremiumButton(
                  label: _isSimulating
                      ? 'Simulating futures…'
                      : 'Run simulation',
                  icon: _isSimulating
                      ? LucideIcons.loader
                      : LucideIcons.sparkles,
                  onPressed: _isSimulating ? null : _runSimulation,
                ),
                if (_simError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _simError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AlterPalette.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          scenarios.when(
            data: (items) => items.isEmpty
                ? _EmptyScenarios(onRun: _runSimulation)
                : ResponsiveGrid(
                    mediumColumns: 2,
                    expandedColumns: 3,
                    children: [
                      for (final s in items) _ScenarioCard(scenario: s),
                    ],
                  ),
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 170,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Text('Unable to load scenarios: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isSimulating = true;
      _simError = '';
    });

    Object? backendError;
    try {
      final profile = ref.read(userProfileProvider).asData?.value;
      if (!_hasProfileSignal(profile)) {
        setState(
          () => _simError =
              'Complete your profile with skills, goals, or interests before running the simulator.',
        );
        return;
      }
      final name = profile?.displayName.isNotEmpty == true
          ? profile!.displayName
          : 'profile not provided';
      final role = profile?.role.trim() ?? '';
      final goals = profile?.goals.join('; ') ?? '';
      final riskPct = (_riskTolerance * 100).round();
      final horizonMo = (_timeHorizon * 60).round();

      final config = await ref.read(backendConfigProvider.future);
      final serviceUrl = config.gatewayUrl;
      if (serviceUrl.isNotEmpty) {
        final client = BackendFeatureApiClient(baseUrl: serviceUrl);
        try {
          final scenarios = await client.simulateFutures(
            profile: profile,
            riskTolerance: _riskTolerance,
            horizonMonths: horizonMo,
          );
          client.close();
          if (scenarios.isNotEmpty) {
            await _persistScenarios(scenarios);
            ref.invalidate(futureScenariosProvider);
            return;
          }
        } catch (error) {
          backendError = error;
          client.close();
        }
      }

      final openai = ref.read(openAIServiceProvider);
      if (openai == null) {
        final backendMessage = backendError == null
            ? ''
            : ' Backend failed: ${backendError.toString().replaceFirst('Exception: ', '')}';
        setState(
          () => _simError =
              'Connect the backend gateway or sign in with AI access.$backendMessage',
        );
        return;
      }

      final raw = await openai.chat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are a strategic foresight AI. Generate 3 distinct, plausible future scenarios. Return ONLY valid JSON, no markdown.',
          },
          {
            'role': 'user',
            'content':
                'Generate 3 future scenarios for $name ($role). Goals: $goals. Risk tolerance: $riskPct%. Time horizon: $horizonMo months.\n\nReturn JSON:\n{"scenarios": [{"title": "...", "horizon": "X months", "probability": 0.0-1.0, "upside": "...", "risk": "...", "levers": ["lever1", "lever2", "lever3"]}]}',
          },
        ],
        temperature: 0.78,
        maxTokens: 900,
      );

      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')
            .replaceFirst(RegExp(r'\n?\s*```$'), '');
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final list = (json['scenarios'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final scenarios = <FutureScenario>[];
      for (final s in list) {
        final title = s['title']?.toString().trim() ?? '';
        final probability = s['probability'];
        if (title.isEmpty || probability is! num) {
          continue;
        }
        scenarios.add(
          FutureScenario(
            title: title,
            horizon: s['horizon']?.toString() ?? '$horizonMo months',
            probability: probability.toDouble(),
            upside: s['upside']?.toString() ?? '',
            risk: s['risk']?.toString() ?? '',
            levers: (s['levers'] as List<dynamic>?)?.cast<String>() ?? const [],
          ),
        );
      }
      await _persistScenarios(scenarios);
      ref.invalidate(futureScenariosProvider);
    } catch (e) {
      setState(() => _simError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Future<void> _persistScenarios(List<FutureScenario> scenarios) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('future_scenarios')
        .delete()
        .eq('user_id', userId);

    for (final s in scenarios) {
      await Supabase.instance.client.from('future_scenarios').insert({
        'user_id': userId,
        'title': s.title,
        'horizon': s.horizon,
        'probability': s.probability,
        'upside': s.upside,
        'risk': s.risk,
        'levers': s.levers,
      });
    }
  }
}

bool _hasProfileSignal(UserProfile? profile) {
  if (profile == null) return false;
  return [
    profile.displayName,
    profile.role,
    profile.careerStage,
    profile.industry,
    ...profile.skills,
    ...profile.goals,
    ...profile.interests,
  ].any((item) => item.trim().isNotEmpty);
}

class _EmptyScenarios extends StatelessWidget {
  const _EmptyScenarios({required this.onRun});

  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        children: [
          const Icon(LucideIcons.route, size: 48, color: AlterPalette.iris),
          const SizedBox(height: 16),
          Text(
            'No scenarios yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run the simulator to generate AI-powered future paths.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: 'Run simulation',
            icon: LucideIcons.sparkles,
            onPressed: onRun,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AlterPalette.iris,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final FutureScenario scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumChip(
            label: scenario.horizon,
            selected: true,
            icon: LucideIcons.clock,
          ),
          const SizedBox(height: 18),
          Text(
            scenario.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            scenario.upside,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: scenario.probability,
              minHeight: 8,
              backgroundColor: AlterPalette.iris.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AlterPalette.iris,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(scenario.probability * 100).round()}% probability',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AlterPalette.iris,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            scenario.risk,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.38,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lever in scenario.levers) PremiumChip(label: lever),
            ],
          ),
        ],
      ),
    );
  }
}

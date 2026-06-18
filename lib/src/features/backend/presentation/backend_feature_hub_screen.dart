import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/routes.dart';
import '../../agent/application/notification_monitor.dart';
import '../../contextos/application/openclaw_adapter.dart';
import '../../device_control/application/phone_control_controller.dart';
import '../../voice/application/native_wake_service_controller.dart';
import '../application/backend_config_controller.dart';
import '../data/backend_api_client.dart';

final backendHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) async {
    final config = await ref.watch(backendConfigProvider.future);
    if (!config.hasGateway) return null;
    final client = BackendApiClient(baseUrl: config.gatewayUrl);
    ref.onDispose(client.close);
    return client.getJson('/v1/system/health');
  },
);

class BackendFeatureHubScreen extends ConsumerWidget {
  const BackendFeatureHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(backendConfigProvider).value;
    final health = ref.watch(backendHealthProvider);
    final phone = ref.watch(phoneControlControllerProvider);
    final monitor = ref.watch(notificationMonitorProvider);
    final wake = ref.watch(nativeWakeServiceControllerProvider);
    final clawQueue = ref.watch(openClawQueueProvider);

    final services = backendFeatureSpecs;
    final statusMap = _statusMap(health.value);
    final healthy = statusMap.values.where((s) => s == 'ok').length;
    final configured = config?.hasGateway == true;

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALTER BACKEND',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AlterPalette.iris,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GradientText(
                      'Every service,\none control surface.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      configured
                          ? 'Gateway: ${config!.gatewayUrl}'
                          : 'No gateway is saved yet. Add your computer LAN URL in Settings.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Set gateway URL',
                icon: const Icon(LucideIcons.pencil, size: 18),
                onPressed: () =>
                    _editGateway(context, ref, config?.gatewayUrl ?? ''),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Refresh backend',
                icon: const Icon(LucideIcons.refresh_cw, size: 18),
                onPressed: () {
                  ref.invalidate(backendHealthProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              MetricTile(
                label: 'Gateway',
                value: configured ? 'ON' : 'OFF',
                detail: configured
                    ? 'Flutter can reach a saved backend URL.'
                    : 'Open Settings and add the gateway URL.',
                icon: configured ? LucideIcons.server : LucideIcons.cloud_off,
                accent: configured ? AlterPalette.mint : AlterPalette.slate,
              ),
              MetricTile(
                label: 'Healthy services',
                value: health.isLoading ? '...' : '$healthy/${services.length}',
                detail: health.hasError
                    ? 'Health request failed.'
                    : 'Reported by /v1/system/health.',
                icon: LucideIcons.activity,
                accent: health.hasError
                    ? AlterPalette.amber
                    : AlterPalette.cyan,
              ),
              MetricTile(
                label: 'Visible features',
                value: '${services.length}',
                detail: 'Every backend module has a frontend surface.',
                icon: LucideIcons.layout_dashboard,
                accent: AlterPalette.iris,
              ),
              const MetricTile(
                label: 'Phone bridge',
                value: 'Native',
                detail: 'Permissions, wake, accessibility, OpenClaw.',
                icon: LucideIcons.smartphone,
                accent: AlterPalette.amber,
              ),
            ],
          ),
          if (health.hasError) ...[
            const SizedBox(height: 12),
            _InlineNote(
              text:
                  'Backend health failed: ${health.error.toString().replaceFirst('Exception: ', '')}',
              color: AlterPalette.amber,
            ),
          ],
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Backend services',
            subtitle:
                'Tap any card for endpoints, live status, and the matching app screen.',
            trailing: PremiumButton(
              compact: true,
              icon: LucideIcons.settings,
              label: 'Settings',
              onPressed: () => context.go(AlterRoutes.settings),
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              for (final spec in services)
                _ServiceCard(
                  spec: spec,
                  status: statusMap[spec.backendName],
                  configured: configured,
                ),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Native phone bridge',
            subtitle:
                'Wake word, permissions, notifications, Accessibility control, OpenClaw, and the agent executor.',
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              _NativeBridgeTile(
                title: 'Hey Alter Wake',
                subtitle: 'Foreground microphone service and wake detector.',
                status: wake.running
                    ? 'running'
                    : wake.supported
                    ? 'ready'
                    : 'unavailable',
                selected: wake.running,
                icon: LucideIcons.radio,
                color: AlterPalette.cyan,
                route: AlterRoutes.voice,
              ),
              _NativeBridgeTile(
                title: 'Notification Monitor',
                subtitle: 'Reads notification text after Android approval.',
                status: monitor.enabled
                    ? 'monitoring'
                    : monitor.granted
                    ? 'granted'
                    : 'needs access',
                selected: monitor.enabled,
                icon: LucideIcons.bell_ring,
                color: AlterPalette.amber,
                route: AlterRoutes.feed,
              ),
              _NativeBridgeTile(
                title: 'Phone Control',
                subtitle: 'Visible-screen read, tap, type, scroll, navigation.',
                status: phone.accessibilityEnabled ? 'enabled' : 'needs access',
                selected: phone.accessibilityEnabled,
                icon: LucideIcons.accessibility,
                color: AlterPalette.mint,
                route: AlterRoutes.openclaw,
              ),
              _NativeBridgeTile(
                title: 'Permission Hub',
                subtitle: 'All assistant permissions in one reversible place.',
                status: phone.deviceAdminStatus?.managed == true
                    ? 'admin ready'
                    : 'permission hub',
                selected: phone.deviceAdminStatus?.managed == true,
                icon: LucideIcons.shield_check,
                color: AlterPalette.iris,
                route: AlterRoutes.permissions,
              ),
              _NativeBridgeTile(
                title: 'Agent Tool Executor',
                subtitle: 'Planner calls real tools instead of only planning.',
                status: 'wired',
                selected: true,
                icon: LucideIcons.bot,
                color: AlterPalette.aura,
                route: AlterRoutes.agent,
              ),
              _NativeBridgeTile(
                title: 'OpenClaw Queue',
                subtitle: 'User-confirmed execution for risky actions.',
                status:
                    '${clawQueue.where((a) => a.stage == ClawStage.queued).length} queued',
                selected: clawQueue.any((a) => a.stage == ClawStage.queued),
                icon: LucideIcons.wand_sparkles,
                color: AlterPalette.amber,
                route: AlterRoutes.openclaw,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'ContextOS surfaces',
            subtitle:
                'The local phone intelligence layer is also reachable from here.',
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              _SurfaceTile(
                'Digital Twin',
                'Data sources and autonomy',
                LucideIcons.brain,
                AlterPalette.aura,
                AlterRoutes.twin,
              ),
              _SurfaceTile(
                'LifeShield',
                'Message/link/payment safety',
                LucideIcons.shield_check,
                AlterPalette.mint,
                AlterRoutes.shield,
              ),
              _SurfaceTile(
                'OpenClaw',
                'Confirmation queue',
                LucideIcons.wand_sparkles,
                AlterPalette.amber,
                AlterRoutes.openclaw,
              ),
              _SurfaceTile(
                'Memory',
                'Trusted sources',
                LucideIcons.database,
                AlterPalette.iris,
                AlterRoutes.memory,
              ),
              _SurfaceTile(
                'DayTwin',
                'Today simulation',
                LucideIcons.calendar_clock,
                AlterPalette.cyan,
                AlterRoutes.dayTwin,
              ),
              _SurfaceTile(
                'Decision DNA',
                'Learned patterns',
                LucideIcons.dna,
                AlterPalette.mint,
                AlterRoutes.decisionDna,
              ),
              _SurfaceTile(
                'Edge Model',
                'On-device Gemma',
                LucideIcons.cpu,
                AlterPalette.cyan,
                AlterRoutes.edge,
              ),
              _SurfaceTile(
                'Privacy',
                'Data controls',
                LucideIcons.lock,
                AlterPalette.danger,
                AlterRoutes.privacy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BackendServiceDetailScreen extends ConsumerWidget {
  const BackendServiceDetailScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = backendFeatureSpecs.firstWhere(
      (item) => item.id == serviceId,
      orElse: () => backendFeatureSpecs.first,
    );
    final theme = Theme.of(context);
    final config = ref.watch(backendConfigProvider).value;
    final health = ref.watch(backendHealthProvider);
    final status = _statusMap(health.value)[spec.backendName];
    final serviceUrl = config?.gatewayUrl ?? '';

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            tooltip: 'Back',
            icon: const Icon(LucideIcons.arrow_left, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AlterRoutes.backend);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: spec.color.withValues(alpha: 0.24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Icon(spec.icon, color: spec.color, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      spec.title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spec.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              MetricTile(
                label: 'Status',
                value: status == null ? 'N/A' : status.toUpperCase(),
                detail: health.hasError
                    ? 'Gateway health is unavailable.'
                    : 'Live health from the backend.',
                icon: status == 'ok' ? LucideIcons.check : LucideIcons.activity,
                accent: _statusColor(status),
              ),
              MetricTile(
                label: 'Frontend',
                value: spec.route == null ? 'Detail' : 'Ready',
                detail: spec.route == null
                    ? 'This detail screen is the app surface.'
                    : 'A dedicated feature screen exists.',
                icon: LucideIcons.monitor_smartphone,
                accent: AlterPalette.iris,
              ),
              MetricTile(
                label: 'Base URL',
                value: serviceUrl.isEmpty ? 'Unset' : 'Live',
                detail: serviceUrl.isEmpty
                    ? 'Configure the gateway URL.'
                    : serviceUrl,
                icon: LucideIcons.link,
                accent: AlterPalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Frontend action',
                  subtitle: spec.route == null
                      ? 'This backend did not have a standalone screen before, so this detail view is its control surface.'
                      : 'Open the screen wired to this backend.',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        icon: spec.icon,
                        label: spec.route == null
                            ? 'Stay on detail'
                            : 'Open feature',
                        onPressed: spec.route == null
                            ? null
                            : () => context.go(spec.route!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.refresh_cw, size: 16),
                        label: const Text('Refresh status'),
                        onPressed: () => ref.invalidate(backendHealthProvider),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Endpoints',
                  subtitle: 'The backend contract now visible from the app.',
                ),
                const SizedBox(height: 12),
                for (final endpoint in spec.endpoints)
                  _EndpointRow(endpoint: endpoint),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'What this powers',
                  subtitle: 'How this backend maps into ALTER.',
                ),
                const SizedBox(height: 12),
                for (final item in spec.capabilities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.check, color: spec.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.spec,
    required this.status,
    required this.configured,
  });

  final BackendFeatureSpec spec;
  final String? status;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go('${AlterRoutes.backend}/${spec.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 205),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(spec.icon, color: spec.color, size: 22),
                  ),
                ),
                const Spacer(),
                PremiumChip(
                  label: !configured
                      ? 'configure'
                      : status == null
                      ? 'unknown'
                      : status!,
                  selected: status == 'ok',
                  icon: status == 'ok'
                      ? LucideIcons.check
                      : LucideIcons.activity,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              spec.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              spec.shortDescription,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                height: 1.35,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${spec.endpoints.length} endpoints',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: spec.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(
                  LucideIcons.arrow_right,
                  size: 17,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.route,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go(route),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevron_right, size: 16),
        ],
      ),
    );
  }
}

class _NativeBridgeTile extends StatelessWidget {
  const _NativeBridgeTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.selected,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool selected;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 23),
              const Spacer(),
              PremiumChip(
                label: status,
                selected: selected,
                icon: selected ? LucideIcons.check : LucideIcons.activity,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.endpoint});

  final String endpoint;

  @override
  Widget build(BuildContext context) {
    final method = endpoint.split(' ').first;
    final path = endpoint.substring(method.length).trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: PremiumChip(
              label: method,
              selected: method == 'GET',
              icon: method == 'GET' ? LucideIcons.download : LucideIcons.upload,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              path,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Row(
        children: [
          Icon(LucideIcons.triangle_alert, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editGateway(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final controller = TextEditingController(text: current);
  final url = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Backend gateway URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://your-tunnel.trycloudflare.com',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Point ALTER at your running backend. Cloudflare quick-tunnels '
            'change URL on restart — paste the new one here if it rotates.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.3),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (url == null || url.isEmpty) return;
  await ref.read(backendConfigProvider.notifier).setGatewayUrl(url);
  ref.invalidate(backendHealthProvider);
}

Map<String, String> _statusMap(Map<String, dynamic>? health) {
  final services = health?['services'];
  if (services is! List) return const <String, String>{};
  return {
    'api_gateway': 'ok',
    for (final service in services.whereType<Map<String, dynamic>>())
      if (service['name'] is String)
        service['name'] as String: '${service['status']}',
  };
}

Color _statusColor(String? status) {
  return switch (status) {
    'ok' => AlterPalette.mint,
    'degraded' => AlterPalette.amber,
    'error' || 'offline' => AlterPalette.danger,
    _ => AlterPalette.slate,
  };
}

class BackendFeatureSpec {
  const BackendFeatureSpec({
    required this.id,
    required this.backendName,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.icon,
    required this.color,
    required this.endpoints,
    required this.capabilities,
    this.service,
    this.route,
  });

  final String id;
  final String backendName;
  final String title;
  final String shortDescription;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> endpoints;
  final List<String> capabilities;
  final BackendService? service;
  final String? route;
}

const backendFeatureSpecs = <BackendFeatureSpec>[
  BackendFeatureSpec(
    id: 'api-gateway',
    backendName: 'api_gateway',
    title: 'API Gateway',
    shortDescription:
        'The single Flutter entrypoint for health, mission, life feed, settings, integrations, and intelligence orchestration.',
    description:
        'The API Gateway is the client-facing edge. It discovers service routes, checks health, composes mission briefings, runs the decision kernel, records outcomes, builds the Future Twin, captures proof, and powers the voice action runtime.',
    icon: LucideIcons.server,
    color: AlterPalette.iris,
    route: AlterRoutes.mission,
    endpoints: [
      'GET /v1/system/health',
      'GET /v1/gateway/routes',
      'GET /v1/gateway/architecture',
      'POST /v1/mission/briefing',
      'GET /v1/life-feed',
      'GET /v1/user/settings',
      'PATCH /v1/user/settings',
      'GET /v1/integrations',
      'GET /v1/multilingual/languages',
      'POST /v1/multilingual/chat',
      'POST /v1/multilingual/translate',
      'POST /v1/multilingual/detect-language',
      'POST /v1/multilingual/text-to-speech',
      'POST /v1/multilingual/speech-to-text',
      'GET /v1/security/consent-ledger',
      'POST /v1/security/consent',
      'POST /v1/data-ingestion/import',
      'POST /v1/agent/plan',
      'GET /v1/privacy/export',
      'POST /v1/privacy/delete',
      'POST /v1/orchestration/future-os',
      'POST /v1/intelligence/decide',
      'POST /v1/intelligence/outcomes',
      'POST /v1/intelligence/future-twin',
      'POST /v1/proof/capture',
      'POST /v1/voice/action-runtime',
    ],
    capabilities: [
      'Mission Control dashboard and health status.',
      'Life Feed and settings surfaces.',
      'Decision Intelligence, outcome learning, Future Twin, and proof capture.',
      'Voice command runtime for Hey Alter responses.',
      'Sarvam-backed multilingual chat, translation, STT, TTS, and language detection.',
      'Consent, safe ingestion, planner, audit, export, and delete controls.',
    ],
  ),
  BackendFeatureSpec(
    id: 'sarvam-speech',
    backendName: 'api_gateway',
    title: 'Sarvam Speech Stack',
    shortDescription:
        'Backend STT, TTS, language detection, chat, and translation for Indian-language voice turns.',
    description:
        'Sarvam Speech Stack runs through the API Gateway so API keys stay off the APK. It can detect language, transcribe uploaded audio, synthesize localized speech, translate text, and localize Hey Alter responses when SARVAM_API_KEY is configured.',
    icon: LucideIcons.audio_lines,
    color: AlterPalette.cyan,
    route: AlterRoutes.voice,
    endpoints: [
      'GET /v1/multilingual/languages',
      'POST /v1/multilingual/chat',
      'POST /v1/multilingual/translate',
      'POST /v1/multilingual/detect-language',
      'POST /v1/multilingual/text-to-speech',
      'POST /v1/multilingual/speech-to-text',
      'POST /v1/voice/action-runtime',
    ],
    capabilities: [
      'Supports all listed Indian languages plus major foreign UI options.',
      'Keeps Sarvam keys in the backend environment, not inside the APK.',
      'Falls back to deterministic local responses when the key is missing.',
      'Voice screen shows provider and response-language status.',
    ],
  ),
  BackendFeatureSpec(
    id: 'consent-security',
    backendName: 'api_gateway',
    title: 'Consent + Security',
    shortDescription:
        'Explicit consent ledger, permission requirements, and action audit boundaries.',
    description:
        'Consent + Security tracks what data sources are allowed, what Android permission each capability needs, retention windows, and which actions must remain reversible. It is designed around user-approved Android surfaces, not hidden full-phone scraping.',
    icon: LucideIcons.shield_check,
    color: AlterPalette.iris,
    route: AlterRoutes.permissions,
    endpoints: [
      'GET /v1/security/consent-ledger',
      'POST /v1/security/consent',
      'GET /v1/privacy/export',
      'POST /v1/privacy/delete',
    ],
    capabilities: [
      'Permission Hub can map Android approvals to backend consent records.',
      'Every sensitive ability is explicit and reversible.',
      'Privacy export/delete controls are visible from the app.',
    ],
  ),
  BackendFeatureSpec(
    id: 'safe-ingestion',
    backendName: 'api_gateway',
    title: 'Safe Data Ingestion',
    shortDescription:
        'Manual imports and Android-approved surfaces turned into memory candidates.',
    description:
        'Safe Data Ingestion accepts user-selected notes, files, exports, notification snippets, and metadata. It rejects silent background chat scraping and requires consent before raw content becomes memory.',
    icon: LucideIcons.folder_input,
    color: AlterPalette.mint,
    route: AlterRoutes.memory,
    endpoints: [
      'POST /v1/data-ingestion/import',
      'POST /v1/memory/items',
      'POST /v1/memory/search',
      'POST /v1/memory/retrieve',
    ],
    capabilities: [
      'Turns imported items into structured memory candidates.',
      'Blocks silent scrape modes at the gateway.',
      'Feeds ContextOS Memory after user approval.',
    ],
  ),
  BackendFeatureSpec(
    id: 'agent-planner',
    backendName: 'api_gateway',
    title: 'Agent Planner',
    shortDescription:
        'Converts goals into confirmable phone tools: intents, drafts, and OpenClaw actions.',
    description:
        'Agent Planner separates reasoning from execution. It produces tool steps, confirmation requirements, Accessibility requirements, and policy warnings before the phone executor touches the device.',
    icon: LucideIcons.workflow,
    color: AlterPalette.aura,
    route: AlterRoutes.agent,
    endpoints: ['POST /v1/agent/plan', 'POST /v1/voice/action-runtime'],
    capabilities: [
      'Plans real tools instead of only returning assistant text.',
      'Requires confirmation for communication and Accessibility actions.',
      'Blocks bypass, password, and silent-control requests.',
    ],
  ),
  BackendFeatureSpec(
    id: 'voice-gateway',
    backendName: 'voice_gateway',
    title: 'Voice Gateway',
    shortDescription:
        'Turns Hey Alter transcripts into wake state, intent, route targets, and spoken response.',
    description:
        'Voice Gateway is the phone-first assistant backend. It parses wake commands, classifies intent, and routes the action graph into future simulation, council, opportunities, memory, Lens, OfficeKit, social graph, and reputation.',
    service: BackendService.voiceGateway,
    route: AlterRoutes.voice,
    icon: LucideIcons.mic,
    color: AlterPalette.cyan,
    endpoints: [
      'GET /v1/voice/architecture',
      'POST /v1/voice/session',
      'POST /v1/voice/action-runtime',
    ],
    capabilities: [
      'Hey Alter wake command interpretation.',
      'Voice action graph and follow-up questions.',
      'Agent fallback when direct AI access is not available.',
    ],
  ),
  BackendFeatureSpec(
    id: 'clone-council',
    backendName: 'clone_council',
    title: 'Clone Council',
    shortDescription:
        'Multi-agent debate, challenges, consensus, risks, and action plan.',
    description:
        'Clone Council runs a structured debate between strategic personas, challenges assumptions, revises opinions, and returns a consensus action plan.',
    service: BackendService.cloneCouncil,
    route: AlterRoutes.council,
    icon: LucideIcons.messages_square,
    color: AlterPalette.iris,
    endpoints: [
      'GET /v1/clone-council/agents',
      'POST /v1/clone-council/debate',
    ],
    capabilities: [
      'Visible council agents on the frontend.',
      'Backend-first debate button with OpenAI fallback.',
      'Action steps persisted into the clone council cache.',
    ],
  ),
  BackendFeatureSpec(
    id: 'future-simulation',
    backendName: 'future_simulation',
    title: 'Future Simulation',
    shortDescription:
        'Structured future paths, timelines, salary/skill/network projections, risks, and opportunities.',
    description:
        'Future Simulation models three plausible futures from profile, skills, goals, experience, interests, risk tolerance, and time horizon.',
    service: BackendService.futureSimulation,
    route: AlterRoutes.simulator,
    icon: LucideIcons.route,
    color: AlterPalette.cyan,
    endpoints: [
      'GET /v1/future-simulation/architecture',
      'POST /v1/future-simulation/simulate',
    ],
    capabilities: [
      'Future Simulator cards and run button.',
      'Mission Control orchestration.',
      'Future Twin trajectory inputs.',
    ],
  ),
  BackendFeatureSpec(
    id: 'memory-system',
    backendName: 'memory_system',
    title: 'Memory System',
    shortDescription:
        'Durable memory, search, retrieval, timeline, and short-term promotion.',
    description:
        'Memory System stores and retrieves structured context for decisions, proof, daily briefs, and personalized reasoning.',
    service: BackendService.memorySystem,
    route: AlterRoutes.memory,
    icon: LucideIcons.database,
    color: AlterPalette.aura,
    endpoints: [
      'GET /v1/memory/architecture',
      'POST /v1/memory/items',
      'GET /v1/memory/items/{memory_id}',
      'PATCH /v1/memory/items/{memory_id}',
      'POST /v1/memory/items/{memory_id}/archive',
      'POST /v1/memory/search',
      'POST /v1/memory/retrieve',
      'POST /v1/memory/short-term',
      'POST /v1/memory/short-term/promote',
      'GET /v1/memory/users/{user_id}/timeline',
    ],
    capabilities: [
      'Trusted source UI through ContextOS Memory.',
      'Decision and proof memory write-back.',
      'Search and retrieve context for the intelligence kernel.',
    ],
  ),
  BackendFeatureSpec(
    id: 'opportunity-engine',
    backendName: 'opportunity_engine',
    title: 'Opportunity Engine',
    shortDescription:
        'Crawl, normalize, categorize, rank, and recommend opportunities.',
    description:
        'Opportunity Engine turns public sources and user profile into ranked recommendations with fit reasons, why-now signals, next actions, and risks.',
    service: BackendService.opportunityEngine,
    route: AlterRoutes.radar,
    icon: LucideIcons.radar,
    color: AlterPalette.mint,
    endpoints: [
      'GET /v1/opportunities/sources',
      'POST /v1/opportunities/crawl',
      'POST /v1/opportunities/normalize',
      'POST /v1/opportunities/categorize',
      'POST /v1/opportunities/rank',
      'POST /v1/opportunities/recommend',
      'POST /v1/opportunities/pipeline',
    ],
    capabilities: [
      'Opportunity Radar cards.',
      'Life Feed opportunity strip.',
      'Mission Control and Future Twin arbitrage inputs.',
    ],
  ),
  BackendFeatureSpec(
    id: 'social-graph',
    backendName: 'social_graph',
    title: 'Social Graph',
    shortDescription:
        'People, relationships, mutual connections, recruiters, mentors, and team formation.',
    description:
        'Social Graph is the network intelligence service. It maps people and relationships, discovers paths, recommends mentors/recruiters, and helps form teams.',
    service: BackendService.socialGraph,
    route: AlterRoutes.social,
    icon: LucideIcons.network,
    color: AlterPalette.iris,
    endpoints: [
      'GET /v1/social-graph/architecture',
      'POST /v1/social-graph/people',
      'GET /v1/social-graph/people/{person_id}',
      'POST /v1/social-graph/relationships',
      'POST /v1/social-graph/mutual-connections',
      'POST /v1/social-graph/career-paths',
      'POST /v1/social-graph/discover/recruiters',
      'POST /v1/social-graph/discover/mentors',
      'POST /v1/social-graph/team-formation',
    ],
    capabilities: [
      'Social Graph screen and NFC follow-up path.',
      'Warm-path data for Mission Control and opportunities.',
      'Recruiter, mentor, and team discovery endpoints visible here.',
    ],
  ),
  BackendFeatureSpec(
    id: 'alter-lens',
    backendName: 'alter_lens',
    title: 'ALTER Lens',
    shortDescription:
        'Camera intelligence for resumes, startup decks, event posters, research papers, and products.',
    description:
        'ALTER Lens uploads camera captures, validates image type, runs vision analysis, and returns structured insights, opportunities, recommendations, entities, and memory candidates.',
    service: BackendService.alterLens,
    route: AlterRoutes.lens,
    icon: LucideIcons.scan_eye,
    color: AlterPalette.cyan,
    endpoints: [
      'GET /v1/alter-lens/architecture',
      'POST /v1/alter-lens/analyze',
    ],
    capabilities: [
      'ALTER Lens capture screen.',
      'Backend multipart image analysis with OpenAI fallback.',
      'Memory candidates and Opportunity Radar routing.',
    ],
  ),
  BackendFeatureSpec(
    id: 'reputation-engine',
    backendName: 'reputation_engine',
    title: 'Reputation Engine',
    shortDescription:
        'Trust ledger, score, recent delta, strengths, risks, and recommendations.',
    description:
        'Reputation Engine records trust events and computes the user score that powers Stats, Reputation Dashboard, proof capture, and outcome learning.',
    service: BackendService.reputationEngine,
    route: AlterRoutes.reputation,
    icon: LucideIcons.trophy,
    color: AlterPalette.amber,
    endpoints: [
      'GET /v1/reputation/architecture',
      'POST /v1/reputation/events',
      'GET /v1/reputation/users/{user_id}/events',
      'GET /v1/reputation/users/{user_id}/score',
    ],
    capabilities: [
      'Stats tab score and delta.',
      'Reputation Dashboard event log.',
      'Outcome learning and proof capture score updates.',
    ],
  ),
  BackendFeatureSpec(
    id: 'officekit',
    backendName: 'officekit',
    title: 'OfficeKit',
    shortDescription:
        'Artifacts and briefing generation for the full work loop.',
    description:
        'OfficeKit creates office artifacts and briefings. In the app it is surfaced through the ContextOS Mission Control loop and backend hub detail page.',
    service: BackendService.officeKit,
    route: AlterRoutes.officeKit,
    icon: LucideIcons.briefcase,
    color: AlterPalette.mint,
    endpoints: [
      'GET /v1/officekit/architecture',
      'POST /v1/officekit/artifacts',
      'POST /v1/officekit/briefing',
    ],
    capabilities: [
      'OfficeKit briefing endpoint visible in frontend.',
      'ContextOS Mission Control route.',
      'Voice Gateway route target and Mission orchestration step.',
    ],
  ),
];

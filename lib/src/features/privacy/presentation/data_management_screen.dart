import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/widgets.dart';
import '../../../core/database/supabase_import_service.dart';
import '../../auth/application/auth_provider.dart';
import '../../contextos/application/memory_engine.dart';
import '../../memory/application/memory_review_controller.dart';
import '../../memory/application/memory_store.dart';
import '../../../data/gateway/alter_gateway_api_client.dart';
import '../../portability/application/memory_export_service.dart';
import '../../../data/gateway/alter_gateway_providers.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _exporting = false;
  bool _deleting = false;
  bool _importing = false;
  PrivacyExportSnapshot? _lastExport;
  final _importPathCtrl = TextEditingController();

  @override
  void dispose() {
    _importPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _importCloudExport() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    final path = _importPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() => _importing = true);
    try {
      final result = await ref
          .read(supabaseImportServiceProvider)
          .importFromJsonFile(path, userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.ok
                  ? 'Imported ${result.memoriesImported} memories'
                      '${result.profileImported ? ' + profile' : ''}.'
                  : 'Import finished with ${result.errors.length} issue(s).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _exporting = true);
    try {
      if (AlterGatewayConfig.isConfigured) {
        final snapshot = await ref
            .read(alterGatewayApiClientProvider)
            .exportPrivacy(userId: user.id);
        setState(() => _lastExport = snapshot);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                snapshot.downloadReady
                    ? 'Export ${snapshot.exportId} is ready.'
                    : 'Export queued: ${snapshot.exportId}',
              ),
            ),
          );
        }
        return;
      }
      final package =
          await ref.read(memoryExportServiceProvider).buildExportPackage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Local export ready (${package['format']}, ${package['checksum_sha256']} bytes checksum).',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAll() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all ALTER data?'),
        content: const Text(
          'This requests a gateway privacy delete and clears local memories.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AlterPalette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      if (AlterGatewayConfig.isConfigured) {
        await ref.read(alterGatewayApiClientProvider).deletePrivacy(
              userId: user.id,
            );
      }
      await ref.read(memoryProvider.notifier).clearAll();
      await ref.read(memoryStoreProvider.notifier).deleteAll();
      ref.invalidate(memoryReviewDeckProvider);
      ref.invalidate(memoryPendingCountProvider);
      ref.invalidate(gatewayConsentLedgerProvider);
      ref.invalidate(gatewayUserSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy delete accepted. Local memory cleared.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consent = ref.watch(gatewayConsentLedgerProvider);

    return DeepScaffold(
      title: 'DATA MANAGEMENT',
      subtitle:
          'Export or delete your ALTER footprint through the API gateway.',
      child: ListView(
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Export my data',
                  subtitle: 'Download a structured privacy export from the gateway.',
                ),
                const SizedBox(height: 12),
                PremiumButton(
                  label: _exporting ? 'Exporting…' : 'Request export',
                  icon: LucideIcons.download,
                  onPressed: _exporting || !AlterGatewayConfig.isConfigured
                      ? null
                      : _export,
                ),
                if (_lastExport != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Sections: ${_lastExport!.includedSections.join(', ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Import from cloud export',
                  subtitle:
                      'Paste the path to a Supabase JSON export (memories + profile).',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _importPathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Export file path',
                    hintText: 'C:\\Users\\you\\alter_export.json',
                  ),
                ),
                const SizedBox(height: 12),
                PremiumButton(
                  label: _importing ? 'Importing…' : 'Import JSON',
                  icon: LucideIcons.upload,
                  onPressed: _importing ? null : _importCloudExport,
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
                  title: 'Consent ledger',
                  subtitle: 'Gateway audit of granted data sources.',
                ),
                const SizedBox(height: 8),
                consent.when(
                  loading: () => const Text('Loading consent ledger…'),
                  error: (_, __) => const Text('Consent ledger unavailable.'),
                  data: (snapshot) {
                    if (snapshot == null || snapshot.grants.isEmpty) {
                      return const Text('No consent grants recorded yet.');
                    }
                    return Column(
                      children: snapshot.grants
                          .map(
                            (grant) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                grant.granted
                                    ? LucideIcons.circle_check
                                    : LucideIcons.circle_off,
                                size: 18,
                                color: grant.granted
                                    ? AlterPalette.mint
                                    : AlterPalette.danger,
                              ),
                              title: Text(grant.source),
                              subtitle: Text('${grant.accessLevel} · ${grant.retentionDays}d'),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
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
                  title: 'Delete everything',
                  subtitle: 'Irreversible privacy delete + local memory wipe.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.trash_2, size: 16),
                  label: Text(_deleting ? 'Deleting…' : 'Delete all data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AlterPalette.danger,
                  ),
                  onPressed: _deleting ? null : _deleteAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

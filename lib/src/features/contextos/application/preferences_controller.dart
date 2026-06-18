import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/contextos_models.dart';

class ContextOsPrefs {
  const ContextOsPrefs({
    this.privateModeDefault = false,
    this.cloudConsent = true,
    this.enabledSurfaces = const {
      'notification',
      'share_sheet',
      'camera',
      'mic',
      'qr',
      'install',
      'manual',
    },
  });

  final bool privateModeDefault;
  final bool cloudConsent;
  final Set<String> enabledSurfaces;

  bool isSurfaceEnabled(MomentSource s) => enabledSurfaces.contains(s.id);

  ContextOsPrefs copyWith({
    bool? privateModeDefault,
    bool? cloudConsent,
    Set<String>? enabledSurfaces,
  }) => ContextOsPrefs(
    privateModeDefault: privateModeDefault ?? this.privateModeDefault,
    cloudConsent: cloudConsent ?? this.cloudConsent,
    enabledSurfaces: enabledSurfaces ?? this.enabledSurfaces,
  );
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, ContextOsPrefs>(
      PreferencesController.new,
    );

class PreferencesController extends AsyncNotifier<ContextOsPrefs> {
  @override
  Future<ContextOsPrefs> build() => _load();

  Future<ContextOsPrefs> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const ContextOsPrefs();
    try {
      final row = await Supabase.instance.client
          .from('contextos_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return const ContextOsPrefs();
      final surfaces = row['enabled_surfaces'];
      return ContextOsPrefs(
        privateModeDefault: row['private_mode_default'] == true,
        cloudConsent: row['cloud_consent'] != false,
        enabledSurfaces: surfaces is List
            ? surfaces.map((e) => e.toString()).toSet()
            : const ContextOsPrefs().enabledSurfaces,
      );
    } catch (_) {
      return const ContextOsPrefs();
    }
  }

  Future<void> _save(ContextOsPrefs p) async {
    state = AsyncValue.data(p);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('contextos_preferences').upsert({
        'user_id': userId,
        'private_mode_default': p.privateModeDefault,
        'cloud_consent': p.cloudConsent,
        'enabled_surfaces': p.enabledSurfaces.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> setPrivateDefault(bool v) async {
    final p = (state.asData?.value ?? const ContextOsPrefs()).copyWith(
      privateModeDefault: v,
    );
    await _save(p);
  }

  Future<void> setCloudConsent(bool v) async {
    final p = (state.asData?.value ?? const ContextOsPrefs()).copyWith(
      cloudConsent: v,
    );
    await _save(p);
  }

  Future<void> toggleSurface(MomentSource s) async {
    final cur = state.asData?.value ?? const ContextOsPrefs();
    final next = {...cur.enabledSurfaces};
    if (next.contains(s.id)) {
      next.remove(s.id);
    } else {
      next.add(s.id);
    }
    await _save(cur.copyWith(enabledSurfaces: next));
  }
}

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/application/backend_config_controller.dart';
import '../../backend/data/backend_api_client.dart';
import '../../profile/application/profile_provider.dart';

final socialGraphServiceProvider = Provider<SocialGraphService>(
  (ref) => SocialGraphService(ref),
);

/// Seeds and queries the ALTER social graph from real data: the signed-in user
/// becomes a Person node, device contacts become connected People, and the
/// backend discovery endpoints find warm recruiter/mentor paths through them.
/// All network access is consent-gated (contacts permission) and capped.
class SocialGraphService {
  SocialGraphService(this._ref);

  final Ref _ref;
  static const _personIdKey = 'alter.social.user_person_id';

  Future<String?> _gatewayUrl() async {
    final cfg = await _ref.read(backendConfigProvider.future);
    return cfg.hasGateway ? cfg.gatewayUrl : null;
  }

  /// Ensure the signed-in user exists as a Person node; returns their node id
  /// (cached in prefs so we only create it once). Null if no gateway.
  Future<String?> ensureUserNode() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_personIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final url = await _gatewayUrl();
    if (url == null) return null;

    final profile = _ref.read(userProfileProvider).asData?.value;
    final rawName = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : (Supabase.instance.client.auth.currentUser?.email ?? 'Me');
    final name = rawName.length < 2 ? 'Me' : rawName;

    final client = BackendApiClient(baseUrl: url);
    try {
      final body = await client.postJson('/v1/social-graph/people', {
        'role': 'User',
        'name': name,
        if ((profile?.bio ?? '').isNotEmpty) 'headline': profile!.bio,
        if ((profile?.industry ?? '').isNotEmpty)
          'organization': profile!.industry,
        'skills': profile?.skills ?? const <String>[],
        'interests': profile?.interests ?? const <String>[],
        'goals': profile?.goals ?? const <String>[],
      });
      final id = body?['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await prefs.setString(_personIdKey, id);
      }
      return id;
    } finally {
      client.close();
    }
  }

  /// Import up to [limit] device contacts as People + KNOWS edges from the user.
  /// Returns the count imported, or a negative sentinel:
  /// -1 permission denied, -2 no gateway, -3 could not anchor user node.
  Future<int> importContacts({int limit = 30}) async {
    final url = await _gatewayUrl();
    if (url == null) return -2;
    final userId = await ensureUserNode();
    if (userId == null) return -3;

    final permission =
        await FlutterContacts.permissions.request(PermissionType.read);
    final ok = permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited;
    if (!ok) return -1;

    final all = await FlutterContacts.getAll(
      properties: {ContactProperty.organization, ContactProperty.email},
    );
    // Prefer contacts carrying an organization/title — they're far richer for
    // recruiter/mentor discovery than a bare name.
    final ranked = all
        .where((c) => (c.displayName ?? '').trim().length >= 2)
        .toList()
      ..sort((a, b) {
        int score(Contact c) => c.organizations.isNotEmpty ? 1 : 0;
        return score(b).compareTo(score(a));
      });
    final picked = ranked.take(limit).toList();

    final client = BackendApiClient(baseUrl: url);
    var count = 0;
    try {
      for (final c in picked) {
        final org = c.organizations.isNotEmpty ? c.organizations.first : null;
        final company = org?.name ?? '';
        final title = org?.jobTitle ?? '';
        final email = c.emails.isNotEmpty ? c.emails.first.address : '';
        final name = c.displayName!.trim();
        final person = await client.postJson('/v1/social-graph/people', {
          'role': _inferRole('$title $company'),
          'name': name.length < 2 ? 'Contact' : name,
          if (email.isNotEmpty) 'email': email,
          if (title.isNotEmpty) 'headline': title,
          if (company.isNotEmpty) 'organization': company,
        });
        final pid = person?['id']?.toString();
        if (pid == null || pid.isEmpty) continue;
        await client.postJson('/v1/social-graph/relationships', {
          'from_person_id': userId,
          'to_person_id': pid,
          'relationship_type': 'KNOWS',
          'strength': 0.5,
        });
        count++;
      }
    } finally {
      client.close();
    }
    return count;
  }

  String _inferRole(String text) {
    final t = text.toLowerCase();
    if (t.contains('recruit') ||
        t.contains('talent') ||
        t.contains('hiring') ||
        t.contains(' hr')) {
      return 'Recruiter';
    }
    if (t.contains('professor') ||
        t.contains('prof.') ||
        t.contains('lecturer') ||
        t.contains('faculty')) {
      return 'Professor';
    }
    if (t.contains('founder') ||
        t.contains('ceo') ||
        t.contains('cto') ||
        t.contains('co-founder')) {
      return 'Founder';
    }
    if (t.contains('investor') ||
        t.contains('venture') ||
        t.contains('partner at') ||
        t.contains(' vc')) {
      return 'Investor';
    }
    return 'Student';
  }

  /// Map a free-text role to a valid PersonRole, falling back to keyword
  /// inference over the role + surrounding text.
  String _normalizeRole(String role, String fallbackText) {
    final r = role.toLowerCase().trim();
    const known = {
      'recruiter': 'Recruiter',
      'professor': 'Professor',
      'founder': 'Founder',
      'investor': 'Investor',
      'student': 'Student',
      'user': 'User',
    };
    for (final entry in known.entries) {
      if (r.contains(entry.key)) return entry.value;
    }
    return _inferRole('$role $fallbackText');
  }

  /// Enrich the graph with a rich, manually-described person (far better signal
  /// for discovery than a bare phone contact). The agent structures the user's
  /// natural-language description into these fields before calling this.
  Future<String> rememberPerson({
    required String name,
    String role = '',
    String organization = '',
    String headline = '',
    List<String> skills = const [],
    List<String> interests = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      return 'I need at least a name to remember someone.';
    }
    final url = await _gatewayUrl();
    if (url == null) return 'No backend gateway configured.';
    final userId = await ensureUserNode();
    if (userId == null) {
      return 'Sign in first so I can anchor your network.';
    }
    final client = BackendApiClient(baseUrl: url);
    try {
      final person = await client.postJson('/v1/social-graph/people', {
        'role': _normalizeRole(role, '$headline $organization'),
        'name': cleanName,
        if (organization.isNotEmpty) 'organization': organization,
        if (headline.isNotEmpty) 'headline': headline,
        'skills': skills,
        'interests': interests,
      });
      final pid = person?['id']?.toString();
      if (pid == null || pid.isEmpty) {
        return 'Could not save $cleanName to your network right now.';
      }
      await client.postJson('/v1/social-graph/relationships', {
        'from_person_id': userId,
        'to_person_id': pid,
        'relationship_type': 'KNOWS',
        'strength': 0.6,
      });
      return 'Added $cleanName to your network'
          '${organization.isEmpty ? '' : ' ($organization)'} — I can use them '
          'for warm intros now.';
    } finally {
      client.close();
    }
  }

  /// Discover warm candidates of [kind] ('recruiter' | 'mentor') matched on
  /// [terms]. Returns a concise, voice-ready summary string.
  Future<String> discover({
    required String kind,
    required List<String> terms,
  }) async {
    final url = await _gatewayUrl();
    if (url == null) return 'No backend gateway configured.';
    final userId = await ensureUserNode();
    if (userId == null) {
      return 'Sign in first so I can anchor your network.';
    }

    final cleaned = terms
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .take(12)
        .toList();

    final client = BackendApiClient(baseUrl: url);
    try {
      final isMentor = kind == 'mentor';
      final path = isMentor
          ? '/v1/social-graph/discover/mentors'
          : '/v1/social-graph/discover/recruiters';
      final payload = isMentor
          ? <String, dynamic>{
              'person_id': userId,
              'target_interests': cleaned,
              'target_skills': cleaned,
              'limit': 5,
            }
          : <String, dynamic>{
              'person_id': userId,
              'target_skills': cleaned,
              'limit': 5,
            };
      final body = await client.postJson(path, payload);
      final cands = (body?['candidates'] is List
              ? body!['candidates'] as List
              : const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .take(5)
          .toList();
      if (cands.isEmpty) {
        return 'No warm $kind matches yet. Connect more contacts (say "connect '
            'my contacts") or add the relevant skills to your profile.';
      }
      return cands.map((c) {
        final person =
            c['person'] is Map ? c['person'] as Map : const <dynamic, dynamic>{};
        final name = person['name'] ?? 'Someone';
        final org = person['organization'];
        final mutual = c['mutual_connection_count'] ?? 0;
        final reason = (c['reasons'] is List
                ? c['reasons'] as List
                : const <dynamic>[])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .take(1)
            .join();
        final orgPart = (org == null || org.toString().isEmpty)
            ? ''
            : ' @ $org';
        final reasonPart = reason.isEmpty ? '' : ' — $reason';
        return '$name$orgPart ($mutual mutual)$reasonPart';
      }).join(' | ');
    } finally {
      client.close();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/routes.dart';
import '../application/profile_provider.dart';
import '../domain/user_profile.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _skillInputCtrl = TextEditingController();
  final _goalInputCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  String _careerStage = '';
  final _skills = <String>[];
  final _goals = <String>[];
  bool _keyObscured = true;
  bool _saving = false;
  String _error = '';

  static const _careerStages = [
    'Student',
    'Early career',
    'Mid career',
    'Senior',
    'Executive',
    'Founder',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing profile
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile != null) {
      _nameCtrl.text = profile.displayName;
      _roleCtrl.text = profile.role;
      _industryCtrl.text = profile.industry;
      _bioCtrl.text = profile.bio;
      _keyCtrl.text = profile.openaiKey;
      _careerStage = profile.careerStage;
      _skills.addAll(profile.skills);
      _goals.addAll(profile.goals);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _industryCtrl.dispose();
    _bioCtrl.dispose();
    _skillInputCtrl.dispose();
    _goalInputCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Your ALTER Profile',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help ALTER understand you so it can think, plan, and act with full context.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // ── Identity ────────────────────────────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Your identity',
                  subtitle: 'Who you are and what you do.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'How ALTER should address you',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Current role',
                    hintText: 'e.g. Founder, Senior Engineer, Product Manager',
                    prefixIcon: Icon(LucideIcons.briefcase),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _industryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Industry',
                    hintText: 'e.g. AI, SaaS, Healthcare, Finance',
                    prefixIcon: Icon(LucideIcons.building_2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Career stage',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final stage in _careerStages)
                      PremiumChip(
                        label: stage,
                        selected: _careerStage == stage,
                        onTap: () => setState(() => _careerStage = stage),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bioCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio (optional)',
                    hintText:
                        'A sentence or two about yourself and what you\'re building',
                    prefixIcon: Icon(LucideIcons.file_text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Skills ──────────────────────────────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'What you\'re good at',
                  subtitle:
                      'ALTER uses your skills to give contextually sharp advice.',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillInputCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Add skill',
                          hintText: 'e.g. Flutter, Fundraising, Copywriting',
                          prefixIcon: Icon(LucideIcons.star),
                        ),
                        onSubmitted: _addSkill,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AlterPalette.iris,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      onPressed: () => _addSkill(_skillInputCtrl.text),
                    ),
                  ],
                ),
                if (_skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in _skills)
                        Chip(
                          label: Text(skill),
                          onDeleted: () =>
                              setState(() => _skills.remove(skill)),
                          deleteIcon: const Icon(LucideIcons.x, size: 14),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Goals ───────────────────────────────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Your goals',
                  subtitle:
                      'ALTER aligns every recommendation to what you\'re building toward.',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _goalInputCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Add goal',
                          hintText: 'e.g. Launch ALTER to 500 users',
                          prefixIcon: Icon(LucideIcons.target),
                        ),
                        onSubmitted: _addGoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AlterPalette.iris,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      onPressed: () => _addGoal(_goalInputCtrl.text),
                    ),
                  ],
                ),
                if (_goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final goal in _goals)
                        Chip(
                          label: Text(goal),
                          onDeleted: () => setState(() => _goals.remove(goal)),
                          deleteIcon: const Icon(LucideIcons.x, size: 14),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── OpenAI Key ──────────────────────────────────────────────────────
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'OpenAI API Key',
                  subtitle:
                      'Required to unlock voice AI, Clone Council, Future Simulator, and all intelligence features.',
                  trailing: PremiumChip(
                    label: 'Required',
                    icon: LucideIcons.key_round,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _keyObscured,
                  decoration: InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'sk-...',
                    prefixIcon: const Icon(LucideIcons.key_round),
                    helperText:
                        'Get your key at platform.openai.com → API keys',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _keyObscured ? LucideIcons.eye : LucideIcons.eye_off,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _keyObscured = !_keyObscured),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_error.isNotEmpty) ...[
            Text(
              _error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AlterPalette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          PremiumButton(
            label: _saving ? 'Saving…' : 'Save Profile',
            icon: _saving ? LucideIcons.loader : LucideIcons.save,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/agent'),
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty || _skills.contains(trimmed)) return;
    setState(() => _skills.add(trimmed));
    _skillInputCtrl.clear();
  }

  void _addGoal(String goal) {
    final trimmed = goal.trim();
    if (trimmed.isEmpty || _goals.contains(trimmed)) return;
    setState(() => _goals.add(trimmed));
    _goalInputCtrl.clear();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final existing = ref.read(userProfileProvider).asData?.value;

      final profile = UserProfile(
        id: userId,
        displayName: name,
        role: _roleCtrl.text.trim(),
        careerStage: _careerStage,
        industry: _industryCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        skills: List.from(_skills),
        goals: List.from(_goals),
        interests: existing?.interests ?? const [],
        languages: existing?.languages ?? const ['English'],
        location: existing?.location ?? '',
        availability: existing?.availability ?? '',
        openaiKey: _keyCtrl.text.trim().isNotEmpty
            ? _keyCtrl.text.trim()
            : (existing?.openaiKey ?? ''),
        sarvamKey: existing?.sarvamKey ?? '',
        onboardingDone: true,
      );

      await ref.read(userProfileProvider.notifier).save(profile);
      if (mounted) context.go(AlterRoutes.home);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/auth/application/auth_provider.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/features/profile/domain/user_profile.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _skillInputCtrl = TextEditingController();
  final _goalInputCtrl = TextEditingController();

  String _careerStage = '';
  final _skills = <String>[];
  final _goals = <String>[];
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
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile != null) _load(profile);
  }

  void _load(UserProfile profile) {
    _nameCtrl.text = profile.displayName;
    _roleCtrl.text = profile.role;
    _industryCtrl.text = profile.industry;
    _bioCtrl.text = profile.bio;
    _careerStage = profile.careerStage;
    _skills
      ..clear()
      ..addAll(profile.skills);
    _goals
      ..clear()
      ..addAll(profile.goals);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _industryCtrl.dispose();
    _bioCtrl.dispose();
    _skillInputCtrl.dispose();
    _goalInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProfileProvider, (_, next) {
      final p = next.asData?.value;
      if (p != null && _nameCtrl.text.isEmpty) _load(p);
    });

    return DeepScaffold(
      title: 'EDIT PROFILE',
      bg: const [Color(0xFF2A1D4A), Color(0xFF120E1C), AppColors.bg],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          Text('Only what you tell Alter — nothing invented.',
              style: AppText.body(14, color: AppColors.white(0.55))),
          const SizedBox(height: 16),
          _field('Display name', _nameCtrl),
          const SizedBox(height: 10),
          _field('Current role', _roleCtrl),
          const SizedBox(height: 10),
          _field('Industry', _industryCtrl),
          const SizedBox(height: 14),
          Text('Career stage', style: AppText.body(13, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in _careerStages)
                PillChip(
                  label: stage,
                  selected: _careerStage == stage,
                  onTap: () => setState(() => _careerStage = stage),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _field('Bio (optional)', _bioCtrl, maxLines: 3),
          const SizedBox(height: 18),
          _chipInput('Add skill', _skillInputCtrl, _skills, _addSkill),
          const SizedBox(height: 14),
          _chipInput('Add goal', _goalInputCtrl, _goals, _addGoal),
          const SizedBox(height: 18),
          Text('Languages', style: AppText.body(13, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push(AlterRoutes.languageSettings),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.white(0.14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.watch(userProfileProvider).asData?.value?.languages
                              .join(', ') ??
                          'English',
                      style: AppText.body(14),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.white(0.5)),
                ],
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: AppText.body(13, color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          LimeButton(
            label: _saving ? 'Saving…' : 'Save profile',
            trailing: null,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(12, color: AppColors.white(0.5))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          obscureText: obscure,
          style: AppText.body(15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.white(0.12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipInput(
    String hint,
    TextEditingController ctrl,
    List<String> items,
    void Function(String) onAdd,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _field(hint, ctrl)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onAdd(ctrl.text),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add, color: AppColors.bg),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                GestureDetector(
                  onTap: () => setState(() => items.remove(item)),
                  child: TagChip('$item ×'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _addSkill(String v) {
    final t = v.trim();
    if (t.isEmpty || _skills.contains(t)) return;
    setState(() => _skills.add(t));
    _skillInputCtrl.clear();
  }

  void _addGoal(String v) {
    final t = v.trim();
    if (t.isEmpty || _goals.contains(t)) return;
    setState(() => _goals.add(t));
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
      final userId = ref.read(localUserIdProvider) ?? '';
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
        openaiKey: existing?.openaiKey ?? '',
        sarvamKey: existing?.sarvamKey ?? '',
        onboardingDone: existing?.onboardingDone ?? true,
      );
      await ref.read(userProfileProvider.notifier).save(profile);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

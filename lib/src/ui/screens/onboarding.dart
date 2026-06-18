import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/core/config/alter_gateway_config.dart';
import 'package:alter/src/core/errors/user_facing_error.dart';
import 'package:alter/src/core/utils/responsive.dart';
import 'package:alter/src/data/gateway/alter_gateway_providers.dart';
import 'package:alter/src/features/auth/application/auth_provider.dart';
import 'package:alter/src/features/identity/application/identity_engine.dart';
import 'package:alter/src/features/memory/application/memory_encode_pipeline.dart';
import 'package:alter/src/features/onboarding/application/onboarding_draft_provider.dart';
import 'package:alter/src/features/settings/domain/supported_languages.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/routes.dart';

// Legacy alias — language settings still imports this.
final onboardingLanguagesProvider = Provider<Set<String>>((ref) {
  return ref.watch(onboardingDraftProvider).languages;
});

// ============================================================
// Languages
// ============================================================
class LanguagesScreen extends ConsumerStatefulWidget {
  const LanguagesScreen({super.key});
  @override
  ConsumerState<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends ConsumerState<LanguagesScreen> {
  static const _fallbackLanguages = kSupportedLanguageNames;

  String? _error;

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    final draft = ref.watch(onboardingDraftProvider);
    final selected = draft.languages;
    final catalogAsync = ref.watch(gatewayLanguagesProvider);
    final apiLanguages = catalogAsync.asData?.value.allLanguages
            .map((language) => language.name)
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final languages =
        apiLanguages.isNotEmpty ? apiLanguages : _fallbackLanguages;

    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2C2150), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.6, -1.0),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STEP 1 OF 2', style: AppText.kicker(AppColors.lime)),
                      const SizedBox(height: 14),
                      Text('What languages\ndo you speak?',
                          style: AppText.display(32,
                              weight: FontWeight.w500, height: 1.1)),
                      const SizedBox(height: 10),
                      Text(
                        'Alter thinks natively in each — switch mid-sentence and it keeps up.',
                        style: AppText.body(14.5, color: AppColors.white(0.55)),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 11,
                        runSpacing: 11,
                        children: languages
                            .map((l) => PillChip(
                                  label: l,
                                  selected: selected.contains(l),
                                  onTap: () {
                                    final next = Set<String>.from(selected);
                                    if (next.contains(l)) {
                                      if (next.length > 1) next.remove(l);
                                    } else {
                                      next.add(l);
                                    }
                                    ref
                                        .read(onboardingDraftProvider.notifier)
                                        .setLanguages(next);
                                    setState(() => _error = null);
                                  },
                                ))
                            .toList(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: AppText.body(13, color: AppColors.danger)),
                      ],
                      const SizedBox(height: 40),
                      LimeButton(
                        label: 'Continue',
                        onTap: () {
                          if (selected.isEmpty) {
                            setState(() =>
                                _error = 'Select at least one language.');
                            return;
                          }
                          context.push(AlterRoutes.about);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// About You
// ============================================================
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});
  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  static const roles = [
    'Student', 'Working', 'Job seeker',
    'Founder', 'Career switcher', 'Researcher',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _educationCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _availabilityCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _skillInputCtrl;

  bool _saving = false;
  String? _error;
  late String _role;
  final _skills = <String>[];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingDraftProvider);
    _nameCtrl = TextEditingController(text: draft.displayName);
    _educationCtrl = TextEditingController(text: draft.education);
    _locationCtrl = TextEditingController(text: draft.location);
    _availabilityCtrl = TextEditingController(text: draft.availability);
    _goalCtrl = TextEditingController(text: draft.goal);
    _skillInputCtrl = TextEditingController();
    _role = draft.role;
    _skills.addAll(draft.skills);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _educationCtrl.dispose();
    _locationCtrl.dispose();
    _availabilityCtrl.dispose();
    _goalCtrl.dispose();
    _skillInputCtrl.dispose();
    super.dispose();
  }

  void _syncDraft() {
    ref.read(onboardingDraftProvider.notifier).update(
          ref.read(onboardingDraftProvider).copyWith(
                displayName: _nameCtrl.text,
                role: _role,
                education: _educationCtrl.text,
                skills: List<String>.from(_skills),
                location: _locationCtrl.text,
                availability: _availabilityCtrl.text,
                goal: _goalCtrl.text,
              ),
        );
  }

  void _addSkill() {
    final skill = _skillInputCtrl.text.trim();
    if (skill.isEmpty || _skills.contains(skill)) return;
    setState(() => _skills.add(skill));
    _skillInputCtrl.clear();
    _syncDraft();
  }

  Future<void> _enterAlter() async {
    _syncDraft();
    final draft = ref.read(onboardingDraftProvider);
    if (draft.displayName.trim().isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (_goalCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Describe your future goal.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = ref.read(localUserIdProvider);
      if (userId == null) throw Exception('Vault locked — unlock with your PIN.');

      final existing = ref.read(userProfileProvider).asData?.value;
      final profile = draft.toProfile(
        id: userId,
        openaiKey: existing?.openaiKey ?? '',
        onboardingDone: true,
      );
      await ref.read(userProfileProvider.notifier).save(profile);

      final pipeline = ref.read(memoryEncodePipelineProvider);
      if (draft.goal.trim().isNotEmpty) {
        await pipeline.process(
          rawContent: draft.goal.trim(),
          provenance: 'onboarding_confirmed',
          title: 'Future goal',
        );
      }
      for (final skill in draft.skills) {
        await pipeline.process(
          rawContent: skill,
          provenance: 'onboarding_confirmed',
          title: 'Skill',
        );
      }
      await ref.read(identityEngineProvider.notifier).refreshFromMemories();

      if (AlterGatewayConfig.isConfigured) {
        try {
          await ref.read(alterGatewayApiClientProvider).patchUserSettings(
                userId: userId,
                languages: draft.languages.toList(),
                role: _role,
              );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile saved. Cloud sync is offline — you can retry from Settings.',
                ),
              ),
            );
          }
        }
      }

      ref.read(onboardingDraftProvider.notifier).clear();
      if (mounted) context.go(AlterRoutes.home);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = UserFacingError.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF3A2566), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(-0.6, -1.0),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 2 OF 2', style: AppText.kicker(AppColors.lime)),
                    const SizedBox(height: 14),
                    Text('Tell us more\nabout yourself.',
                        style: AppText.display(32,
                            weight: FontWeight.w500, height: 1.1)),
                    const SizedBox(height: 24),
                    Text('WHERE ARE YOU RIGHT NOW?',
                        style: AppText.kicker(AppColors.white(0.45), size: 12)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: roles
                          .map((r) => PillChip(
                                label: r,
                                selected: _role == r,
                                onTap: () {
                                  setState(() => _role = r);
                                  _syncDraft();
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    _textField('Your name', _nameCtrl, onChanged: (_) => _syncDraft()),
                    const SizedBox(height: 12),
                    _textField('Education / background', _educationCtrl,
                        hint: 'e.g. B.Tech CSE, Year 3',
                        onChanged: (_) => _syncDraft()),
                    const SizedBox(height: 12),
                    _textField('Location & work preference', _locationCtrl,
                        hint: 'e.g. Tier-2 city · Open to remote',
                        onChanged: (_) => _syncDraft()),
                    const SizedBox(height: 12),
                    _textField('Focus hours / availability', _availabilityCtrl,
                        hint: 'e.g. ~15 focus hours / week',
                        onChanged: (_) => _syncDraft()),
                    const SizedBox(height: 20),
                    Text('SKILLS',
                        style: AppText.kicker(AppColors.white(0.45), size: 12)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._skills.map(
                          (s) => InputChip(
                            label: Text(s, style: AppText.body(13)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _skills.remove(s));
                              _syncDraft();
                            },
                            backgroundColor: AppColors.white(0.08),
                            side: BorderSide(color: AppColors.white(0.14)),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _skillInputCtrl,
                            style: AppText.body(14, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add skill',
                              hintStyle:
                                  AppText.body(14, color: AppColors.white(0.4)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: AppColors.white(0.14)),
                              ),
                            ),
                            onSubmitted: (_) => _addSkill(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('FUTURE GOAL',
                        style: AppText.kicker(AppColors.white(0.45), size: 12)),
                    const SizedBox(height: 10),
                    _textField('', _goalCtrl,
                        hint:
                            'I want to become an AI Engineer and ship something of my own within 3 years.',
                        maxLines: 3,
                        onChanged: (_) => _syncDraft()),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: AppText.body(13, color: AppColors.danger)),
                    ],
                    const SizedBox(height: 30),
                    LimeButton(
                      label: _saving ? 'Entering…' : 'Enter Alter',
                      height: 62,
                      onTap: _saving ? null : _enterAlter,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: AppText.body(13, color: AppColors.white(0.55))),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppText.body(15, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body(14, color: AppColors.white(0.35)),
            filled: true,
            fillColor: AppColors.white(0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.white(0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.white(0.12)),
            ),
          ),
        ),
      ],
    );
  }
}

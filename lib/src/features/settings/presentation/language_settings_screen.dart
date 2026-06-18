import 'package:flutter/material.dart';

import 'package:flutter_lucide/flutter_lucide.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/config/alter_gateway_config.dart';

import '../../../core/theme/alter_palette.dart';

import '../../../core/widgets/glass_panel.dart';

import '../../../core/widgets/premium_controls.dart';

import '../../../ui/widgets.dart';

import '../../auth/application/auth_provider.dart';

import '../../../data/gateway/alter_gateway_api_client.dart';

import '../../../data/gateway/alter_gateway_providers.dart';

import '../../onboarding/application/onboarding_draft_provider.dart';

import '../../profile/application/profile_provider.dart';

import '../../profile/domain/user_profile.dart';

import '../domain/supported_languages.dart';



class LanguageSettingsScreen extends ConsumerStatefulWidget {

  const LanguageSettingsScreen({super.key});



  @override

  ConsumerState<LanguageSettingsScreen> createState() =>

      _LanguageSettingsScreenState();

}



class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {

  final _sampleController = TextEditingController(text: 'Good morning, ALTER.');

  String _targetCode = 'hi-IN';

  String _translation = '';

  String _detected = '';

  bool _busy = false;

  String? _saveError;



  @override

  void dispose() {

    _sampleController.dispose();

    super.dispose();

  }



  Future<void> _saveLanguages(Set<String> selectedNames) async {

    setState(() => _saveError = null);

    ref.read(onboardingDraftProvider.notifier).setLanguages(selectedNames);



    final userId = ref.read(localUserIdProvider);

    if (userId == null) {

      setState(() => _saveError = 'Unlock ALTER with your PIN to save languages.');

      return;

    }



    final existing = ref.read(userProfileProvider).asData?.value;

    if (existing != null) {

      await ref.read(userProfileProvider.notifier).save(

            existing.copyWith(languages: selectedNames.toList()),

          );

    }



    if (!AlterGatewayConfig.isConfigured) return;

    try {

      await ref.read(alterGatewayApiClientProvider).patchUserSettings(

            userId: userId,

            languages: selectedNames.toList(),

          );

      ref.invalidate(gatewayUserSettingsProvider);

    } catch (_) {

      // Local profile is saved; gateway sync is optional.

    }

  }



  Future<void> _translate() async {

    if (!AlterGatewayConfig.isConfigured) return;

    setState(() => _busy = true);

    try {

      final result = await ref.read(alterGatewayApiClientProvider).translate(

            text: _sampleController.text.trim(),

            targetLanguageCode: _targetCode,

          );

      setState(() => _translation = result.text);

    } catch (error) {

      setState(() => _translation = 'Error: $error');

    } finally {

      setState(() => _busy = false);

    }

  }



  Future<void> _detect() async {

    if (!AlterGatewayConfig.isConfigured) return;

    setState(() => _busy = true);

    try {

      final result = await ref

          .read(alterGatewayApiClientProvider)

          .detectLanguage(_sampleController.text.trim());

      setState(() => _detected = result.languageCode);

    } catch (error) {

      setState(() => _detected = 'Error: $error');

    } finally {

      setState(() => _busy = false);

    }

  }



  List<String> _languageNames(

    AsyncValue<MultilingualCatalog> catalogAsync,

    UserProfile? profile,

  ) {

    final apiLanguages = catalogAsync.asData?.value?.allLanguages

            .map((language) => language.name)

            .where((name) => name.isNotEmpty)

            .toList(growable: false) ??

        const <String>[];

    if (apiLanguages.isNotEmpty) return apiLanguages;



    final fromProfile = profile?.languages.where((l) => l.isNotEmpty).toList() ??

        const <String>[];

    return {...kSupportedLanguageNames, ...fromProfile}.toList();

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final catalogAsync = ref.watch(gatewayLanguagesProvider);

    final settingsAsync = ref.watch(gatewayUserSettingsProvider);

    final profile = ref.watch(userProfileProvider).asData?.value;

    final selected = profile?.languages.isNotEmpty == true

        ? profile!.languages.toSet()

        : ref.watch(onboardingDraftProvider).languages;

    final languages = _languageNames(catalogAsync, profile);



    return DeepScaffold(
      title: 'LANGUAGES',
      subtitle:
          'Tap languages you speak. Voice replies match your profile languages '
          '(first selected = primary).',
      child: ListView(
        children: [

          const SizedBox(height: 18),

          GlassPanel(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const SectionHeader(

                  title: 'Your languages',

                  subtitle: 'Saved on this phone. Syncs to gateway when online.',

                ),

                const SizedBox(height: 12),

                Wrap(

                  spacing: 10,

                  runSpacing: 10,

                  children: languages

                      .map(

                        (name) => FilterChip(

                          label: Text(name),

                          selected: selected.contains(name),

                          onSelected: (value) async {

                            final next = Set<String>.from(selected);

                            if (value) {

                              next.add(name);

                            } else if (next.length > 1) {

                              next.remove(name);

                            }

                            await _saveLanguages(next);

                            if (mounted) setState(() {});

                          },

                        ),

                      )

                      .toList(),

                ),

                if (_saveError != null)

                  Padding(

                    padding: const EdgeInsets.only(top: 10),

                    child: Text(

                      _saveError!,

                      style: theme.textTheme.bodySmall?.copyWith(

                        color: AlterPalette.danger,

                      ),

                    ),

                  ),

                if (settingsAsync.asData?.value?.languages.isNotEmpty == true)

                  Padding(

                    padding: const EdgeInsets.only(top: 10),

                    child: Text(

                      'Gateway: ${settingsAsync.asData!.value!.languages.join(', ')}',

                      style: theme.textTheme.bodySmall?.copyWith(

                        color: theme.colorScheme.onSurface.withValues(alpha: 0.58),

                      ),

                    ),

                  ),

              ],

            ),

          ),

          if (AlterGatewayConfig.isConfigured) ...[

            const SizedBox(height: 14),

            GlassPanel(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const SectionHeader(

                    title: 'Translate & detect',

                    subtitle: 'Gateway multilingual endpoints.',

                  ),

                  const SizedBox(height: 12),

                  TextField(

                    controller: _sampleController,

                    maxLines: 2,

                    decoration: const InputDecoration(

                      labelText: 'Sample phrase',

                      border: OutlineInputBorder(),

                    ),

                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(

                    value: _targetCode,

                    decoration: const InputDecoration(

                      labelText: 'Target language code',

                      border: OutlineInputBorder(),

                    ),

                    items: (catalogAsync.asData?.value?.allLanguages.isNotEmpty ==

                            true

                        ? catalogAsync.asData!.value!.allLanguages

                        : const [

                            GatewayLanguage(

                              code: 'hi-IN',

                              name: 'Hindi',

                              region: 'India',

                            ),

                            GatewayLanguage(

                              code: 'en-IN',

                              name: 'English',

                              region: 'India',

                            ),

                          ])

                        .map(

                          (language) => DropdownMenuItem(

                            value: language.code,

                            child: Text('${language.name} (${language.code})'),

                          ),

                        )

                        .toList(),

                    onChanged: (value) {

                      if (value != null) setState(() => _targetCode = value);

                    },

                  ),

                  const SizedBox(height: 12),

                  Row(

                    children: [

                      Expanded(

                        child: OutlinedButton(

                          onPressed: _busy ? null : _detect,

                          child: const Text('Detect'),

                        ),

                      ),

                      const SizedBox(width: 10),

                      Expanded(

                        child: PremiumButton(

                          label: _busy ? 'Working…' : 'Translate',

                          compact: true,

                          onPressed: _busy ? null : _translate,

                        ),

                      ),

                    ],

                  ),

                  if (_detected.isNotEmpty)

                    Padding(

                      padding: const EdgeInsets.only(top: 10),

                      child: Text('Detected: $_detected'),

                    ),

                  if (_translation.isNotEmpty)

                    Padding(

                      padding: const EdgeInsets.only(top: 10),

                      child: Text(

                        'Translation: $_translation',

                        style: theme.textTheme.titleSmall?.copyWith(

                          color: AlterPalette.mint,

                        ),

                      ),

                    ),

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }

}



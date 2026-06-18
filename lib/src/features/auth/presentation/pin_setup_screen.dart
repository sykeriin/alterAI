import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/utils/responsive.dart';
import '../../../ui/routes.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../application/auth_provider.dart';
import 'pin_keypad.dart';

enum _PinSetupStep { enter, confirm }

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _PinSetupStep _step = _PinSetupStep.enter;
  String _pin = '';
  String _firstPin = '';
  bool _enableBiometric = false;
  bool _loading = false;
  String? _error;

  void _onDigit(String digit) {
    if (_loading || _pin.length >= 8) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length >= 8) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submitPin() async {
    if (_pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }

    if (_step == _PinSetupStep.enter) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = _PinSetupStep.confirm;
      });
      return;
    }

    if (_pin != _firstPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
        _firstPin = '';
        _step = _PinSetupStep.enter;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(localAuthServiceProvider.notifier).setupAndUnlock(
            _pin,
            enableBiometric: _enableBiometric,
          );
      if (mounted) context.go(AlterRoutes.permissions);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UserFacingError.from(e).message;
          _pin = '';
          _firstPin = '';
          _step = _PinSetupStep.enter;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    final filled = _pin.length;
    final title = _step == _PinSetupStep.enter
        ? 'Create your\nvault PIN.'
        : 'Confirm your\nPIN.';
    final subtitle = _step == _PinSetupStep.enter
        ? '4–8 digits encrypt your memories on this device.'
        : 'Enter the same PIN again to confirm.';

    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2A1F4A), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.0, -1.0),
        orbs: [
          PositionedOrb(
            top: -40,
            left: 0,
            right: 0,
            orb: Orb(
              size: 280,
              blur: 20,
              colors: [AppColors.purple.withValues(alpha: 0.6)],
            ),
          ),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 40, gutter, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.white(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.white(0.14)),
                      ),
                      child: const StarMark(size: 26),
                    ),
                    const SizedBox(height: 26),
                    Text(title, style: AppText.display(34, weight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: AppText.body(15, color: AppColors.white(0.55)),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: PinDots(
                        slots: filled > 0 ? filled.clamp(4, 8) : 4,
                        filled: filled,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _error!,
                          style: AppText.body(13, color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (_step == _PinSetupStep.confirm) ...[
                      const SizedBox(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Unlock with biometrics',
                          style: AppText.body(15, color: AppColors.white(0.85)),
                        ),
                        subtitle: Text(
                          'Use fingerprint or face when available.',
                          style: AppText.body(13, color: AppColors.white(0.45)),
                        ),
                        value: _enableBiometric,
                        activeThumbColor: AppColors.lime,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _enableBiometric = v),
                      ),
                    ],
                    if (_pin.length >= 4 && _pin.length < 8 && !_loading) ...[
                      const SizedBox(height: 20),
                      LimeButton(
                        label: _step == _PinSetupStep.enter
                            ? 'Continue'
                            : 'Confirm PIN',
                        onTap: _submitPin,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.lime),
                        ),
                      )
                    else
                      PinKeypad(
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
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
}

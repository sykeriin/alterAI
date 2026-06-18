import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_key_service.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/utils/responsive.dart';
import '../../../ui/routes.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../application/auth_provider.dart';
import 'pin_keypad.dart';

class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String _pin = '';
  bool _loading = false;
  bool _showBiometric = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available =
        await ref.read(localAuthServiceProvider.notifier).canUseBiometricUnlock();
    if (mounted) setState(() => _showBiometric = available);
    if (available) {
      await _unlockWithBiometric();
    }
  }

  void _onDigit(String digit) {
    if (_loading || _pin.length >= 8) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length >= 8) {
      _unlockWithPin();
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
    await _unlockWithPin();
  }

  void _onUnlocked() {
    if (!mounted) return;
    // Router redirect sends incomplete onboarding to Permissions → Languages → About.
    context.go(AlterRoutes.home);
  }

  Future<void> _unlockWithPin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(localAuthServiceProvider.notifier).unlockWithPin(_pin);
      _onUnlocked();
    } on PinIncorrectException {
      if (mounted) {
        setState(() {
          _error = 'Incorrect PIN. Try again.';
          _pin = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UserFacingError.from(e).message;
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(localAuthServiceProvider.notifier).unlockWithBiometric();
      if (ref.read(localAuthServiceProvider) == LocalAuthState.unlocked) {
        _onUnlocked();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = UserFacingError.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    final filled = _pin.length;

    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2C2150), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.6, -1.0),
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
                    Text(
                      'Welcome back.',
                      style: AppText.display(34, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter your PIN to unlock your encrypted vault.',
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
                    if (_pin.length >= 4 && _pin.length < 8 && !_loading) ...[
                      const SizedBox(height: 20),
                      LimeButton(
                        label: 'Unlock',
                        onTap: _unlockWithPin,
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
                        showBiometric: _showBiometric,
                        onBiometric: _unlockWithBiometric,
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

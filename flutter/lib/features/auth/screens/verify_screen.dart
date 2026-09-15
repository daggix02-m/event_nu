import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/session.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  var _submitting = false;
  var _secondsLeft = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (_submitting || code.length != 6) return;
    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).verifyCode(code);
      if (!mounted) return;
      context.go(AppRoute.home.path);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startResendCountdown() {
    setState(() => _secondsLeft = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = switch (session) {
      AuthStateAuthenticated(:final user) => user,
      _ => null,
    };
    final textTheme = Theme.of(context).textTheme;

    if (user != null && user.isVerified) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: FilledButton(
              onPressed: () => context.go(AppRoute.home.path),
              child: const Text('Continue'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.marginMobile),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Check your inbox', style: textTheme.headlineLarge),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    user == null
                        ? 'We sent a 6-digit code to your email.'
                        : 'We sent a 6-digit code to ${user.email}.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: textTheme.titleMedium?.copyWith(fontSize: 28, letterSpacing: 12),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (v) {
                      if (v.length == 6) _submit();
                    },
                    decoration: const InputDecoration(counterText: ''),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (_secondsLeft > 0)
                    Text(
                      'Resend code in ${_secondsLeft}s',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                    )
                  else
                    TextButton(
                      onPressed: _startResendCountdown,
                      child: const Text('Resend code'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/session.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../../shared/validation/form_errors.dart';
import '../../../shared/widgets/password_strength_meter.dart';
import '../../../shared/widgets/wizard_scaffold.dart';
import '../registration_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  var _obscure = true;
  var _submitting = false;
  var _confirmTouched = false;
  FieldErrors? _serverErrors;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onChange(void Function(RegistrationController c) update) {
    setState(() => _serverErrors = null);
    update(ref.read(registrationControllerProvider.notifier));
  }

  Future<void> _submit() async {
    final controller = ref.read(registrationControllerProvider.notifier);
    if (_submitting || controller.validatePassword() != null) return;
    if (_confirm.text != controller.password) {
      setState(() => _confirmTouched = true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).register(
            email: controller.email,
            password: controller.password,
            username: controller.username,
          );
      // The router redirects to verify (unverified) or home (verified).
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverErrors = mapServerFormError(e));
    } catch (_) {
      if (mounted) {
        setState(() => _serverErrors = const FieldErrors(
          form: 'Something went wrong. Please try again later.',
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(registrationControllerProvider.notifier);
    final draft = ref.watch(registrationControllerProvider);
    final step = draft.step;

    return WizardScaffold(
      index: step,
      count: 2,
      title: 'Join the Addis Radar',
      subtitle: 'Your weekend, mapped. Create an account to never miss what\u2019s popping.',
      onBack: step > 0 ? controller.back : null,
      content: step == 0
          ? _buildAccountDetails(controller)
          : _buildPassword(controller, draft),
      footer: step == 0
          ? _buildAccountFooter(controller)
          : _buildPasswordFooter(),
    );
  }

  Widget _buildAccountDetails(RegistrationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _username,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Handle',
            helperText: '3\u201332 characters \u00b7 unique across Event Nu',
            errorText: _serverErrors?.username ?? controller.validateUsername(),
          ),
          onChanged: (v) => _onChange((c) => c.setUsername(v)),
        ),
        const SizedBox(height: AppSpace.sm),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Email',
            helperText: 'A 6-digit code is sent here to verify your account.',
            errorText: _serverErrors?.email ?? controller.validateEmail(),
          ),
          onChanged: (v) => _onChange((c) => c.setEmail(v)),
        ),
        if (_serverErrors?.form != null) ...[
          const SizedBox(height: AppSpace.sm),
          _FormError(message: _serverErrors!.form!),
        ],
      ],
    );
  }

  Widget _buildPassword(RegistrationController controller, RegistrationDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText:
                _serverErrors?.password ?? controller.validatePassword(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (v) => _onChange((c) => c.setPassword(v)),
        ),
        const SizedBox(height: AppSpace.xs),
        PasswordStrengthMeter(password: draft.password),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: _confirmTouched && _confirm.text != draft.password
                ? 'Passwords do not match'
                : null,
          ),
          onChanged: (_) {
            if (!_confirmTouched) setState(() => _confirmTouched = true);
          },
        ),
        if (_serverErrors?.form != null) ...[
          const SizedBox(height: AppSpace.sm),
          _FormError(message: _serverErrors!.form!),
        ],
      ],
    );
  }

  Widget _buildAccountFooter(RegistrationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: controller.canProceedStep0 ? controller.next : null,
          child: const Text('Continue'),
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          onPressed: () => context.go(AppRoute.signIn.path),
          child: const Text('Have an account? Sign in'),
        ),
      ],
    );
  }

  Widget _buildPasswordFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create account'),
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          onPressed: _submitting
              ? null
              : () => ref.read(registrationControllerProvider.notifier).back(),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.onErrorContainer),
      ),
    );
  }
}
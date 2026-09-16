import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/validation/validators.dart';

/// Draft of the register wizard: only the fields the backend accepts
/// (username, email, password) plus the current wizard [step].
class RegistrationDraft {
  const RegistrationDraft({
    this.username = '',
    this.email = '',
    this.password = '',
    this.step = 0,
  });

  final String username;
  final String email;
  final String password;
  final int step;

  RegistrationDraft copyWith({
    String? username,
    String? email,
    String? password,
    int? step,
  }) {
    return RegistrationDraft(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      step: step ?? this.step,
    );
  }
}

/// Holds the register wizard draft, runs field validation and advances the
/// two-step page flow. The network call itself lives in
/// `SessionController.register`.
class RegistrationController extends Notifier<RegistrationDraft> {
  @override
  RegistrationDraft build() => const RegistrationDraft();

  String get username => state.username.trim();
  String get email => state.email.trim();
  String get password => state.password;

  String? validateUsername([String? value]) =>
      validateHandleInput(value ?? state.username);

  String? validateEmail([String? value]) =>
      validateEmailInput(value ?? state.email);

  String? validatePassword([String? value]) =>
      validatePasswordInput(value ?? state.password);

  bool get canProceedStep0 =>
      validateUsername() == null && validateEmail() == null;

  bool get canProceedStep1 => validatePassword() == null;

  void setUsername(String value) => state = state.copyWith(username: value);

  void setEmail(String value) => state = state.copyWith(email: value);

  void setPassword(String value) => state = state.copyWith(password: value);

  void next() {
    if (state.step >= 1) return;
    if (state.step == 0 && !canProceedStep0) return;
    state = state.copyWith(step: state.step + 1);
  }

  void back() {
    if (state.step == 0) return;
    state = state.copyWith(step: state.step - 1);
  }
}

final registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, RegistrationDraft>(
  RegistrationController.new,
);
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/features/auth/registration_controller.dart';

void main() {
  late ProviderContainer container;
  late RegistrationController controller;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    controller = container.read(registrationControllerProvider.notifier);
  });

  test('starts on step 0 with an empty draft', () {
    expect(controller.state.step, 0);
    expect(controller.state.username, '');
    expect(controller.state.email, '');
    expect(controller.state.password, '');
  });

  test('cannot proceed past account details until username and email are valid', () {
    expect(controller.canProceedStep0, isFalse);

    controller.setUsername('daggi');
    expect(controller.canProceedStep0, isFalse);

    controller.setEmail('dev@eventnu.test');
    expect(controller.canProceedStep0, isTrue);
  });

  test('username validation respects the 3-32 character backend rule', () {
    expect(controller.validateUsername('ab'), isNotNull);
    controller.setUsername('a' * 33);
    expect(controller.validateUsername(), isNotNull);
    controller.setUsername('daggi');
    expect(controller.validateUsername(), isNull);
  });

  test('email validation rejects malformed values', () {
    controller.setEmail('nope');
    expect(controller.validateEmail(), isNotNull);
    controller.setEmail('dev@eventnu.test');
    expect(controller.validateEmail(), isNull);
  });

  test('cannot submit until the password meets the 8-72 backend rule', () {
    controller.setUsername('daggi');
    controller.setEmail('dev@eventnu.test');
    controller.next();
    expect(controller.state.step, 1);
    expect(controller.canProceedStep1, isFalse);

    controller.setPassword('short');
    expect(controller.canProceedStep1, isFalse);

    controller.setPassword('secure-password');
    expect(controller.canProceedStep1, isTrue);
  });

  test('back returns to the previous step', () {
    controller.setUsername('daggi');
    controller.setEmail('dev@eventnu.test');
    controller.next();
    expect(controller.state.step, 1);
    controller.back();
    expect(controller.state.step, 0);
  });

  test('next/back never leave the valid step range', () {
    controller.back();
    expect(controller.state.step, 0);
    controller.setUsername('daggi');
    controller.setEmail('dev@eventnu.test');
    controller.next();
    expect(controller.state.step, 1);
    controller.next(); // no step beyond the last
    expect(controller.state.step, 1);
  });

  test('exposes the trimmed draft fields for submission', () {
    controller.setUsername('  daggi  ');
    controller.setEmail('  dev@eventnu.test  ');
    controller.setPassword('secure-password');
    expect(controller.username, 'daggi');
    expect(controller.email, 'dev@eventnu.test');
    expect(controller.password, 'secure-password');
  });
}
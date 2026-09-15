import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import 'package:event_nu/app/app.dart';
import 'package:event_nu/core/auth/session.dart';

Future<String> _fetchVerifyCode(String email) async {
  final sql =
      "SELECT params->>'verify_code' FROM email_outbox WHERE recipient_email = '$email' "
      "AND template_id = 11 ORDER BY created_at DESC LIMIT 1";
  for (var attempt = 0; attempt < 30; attempt++) {
    final result = await Process.run(
      'docker',
      [
        'exec',
        'event_nu_ci_pg',
        'psql',
        '-U',
        'postgres',
        '-d',
        'event_nu_test',
        '-tAc',
        sql,
      ],
    );
    if (result.exitCode == 0) {
      final code = (result.stdout as String).trim();
      if (code.length == 6) return code;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('verify code not found for $email');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register → verify → home → logout → login', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).clearSession();

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'e2e+$stamp@eventnu.test';
    final username = 'e2e_${stamp % 1000000}';
    const password = 'CorrectHorseBatteryStaple1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const EventNuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), password);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);

    final code = await _fetchVerifyCode(email);
    await tester.enterText(find.byType(TextField), code);
    await tester.pumpAndSettle();

    expect(find.textContaining('Discover'), findsWidgets);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Discover, $username'), findsOneWidget);
  });
}
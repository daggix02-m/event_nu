import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/auth/session.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = switch (session) {
      AuthStateAuthenticated(:final user) => user,
      _ => null,
    };
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Event Nu', style: textTheme.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.marginMobile),
          children: [
            Text(
              user == null ? 'Discover' : 'Discover, ${user.username}',
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Event discovery is coming in the next phase.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            if (user != null && !user.isVerified) ...[
              const SizedBox(height: AppSpace.lg),
              Card(
                color: AppColors.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.mark_email_unread, color: AppColors.onSecondaryContainer),
                  title: const Text('Email not verified yet'),
                  subtitle: const Text('Some actions remain unavailable until you verify.'),
                  trailing: FilledButton(
                    onPressed: () => context.go(AppRoute.verify.path),
                    child: const Text('Verify'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
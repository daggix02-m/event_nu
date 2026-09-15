import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_router.dart';
import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import 'data/engagement_models.dart';
import 'engagement_providers.dart';

class MyRsvpsScreen extends ConsumerWidget {
  const MyRsvpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myRsvpsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Events I'm going to")),
      body: value.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Could not load your RSVPs.',
          onRetry: () => ref.invalidate(myRsvpsControllerProvider),
        ),
        data: (rsvps) {
          if (rsvps.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available,
              title: 'Not going anywhere yet',
              message: 'Tap "I\'m going" on any event to keep it here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myRsvpsControllerProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.sm),
              itemCount: rsvps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) => _RsvpTile(rsvp: rsvps[index]),
            ),
          );
        },
      ),
    );
  }
}

class _RsvpTile extends ConsumerWidget {
  const _RsvpTile({required this.rsvp});

  final MyRsvp rsvp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final visible = rsvp.isVisible;
    return Card(
      color: AppColors.surfaceContainer,
      child: ListTile(
        onTap: () {
          if (visible) context.go(AppRoute.event(rsvp.eventId));
        },
        leading: CircleAvatar(
          backgroundColor: AppColors.neon.withValues(alpha: 0.16),
          child: Icon(visible ? Icons.event : Icons.visibility_off, color: AppColors.neon, size: 20),
        ),
        title: Text(
          visible && rsvp.summary != null && rsvp.summary!.title.isNotEmpty
              ? rsvp.summary!.title
              : 'Unavailable event',
          style: textTheme.titleSmall?.copyWith(color: visible ? AppColors.onSurface : AppColors.onSurfaceVariant),
        ),
        subtitle: rsvp.summary == null
            ? null
            : Text(
                DateFormat('EEE, MMM d · h:mm a').format(rsvp.summary!.startsAt.toLocal()),
                style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.event_busy, color: AppColors.error),
          tooltip: 'Not going',
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(myRsvpsControllerProvider.notifier).cancelGoing(rsvp.eventId);
            } on ApiException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            } catch (_) {
              messenger.showSnackBar(const SnackBar(content: Text('Could not update your RSVP.')));
            }
          },
        ),
      ),
    );
  }
}
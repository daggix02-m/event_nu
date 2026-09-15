import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import 'engagement_providers.dart';
import 'data/engagement_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: value.value?.where((n) => !n.isRead).isEmpty ?? true
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(notificationsControllerProvider.notifier).markAllRead();
                    } on ApiException catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark all'),
          ),
        ],
      ),
      body: value.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Could not load notifications.',
          onRetry: () => ref.invalidate(notificationsControllerProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nothing yet',
              message: 'Updates about your events will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsControllerProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.sm),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return const SizedBox(height: 8);
                }
                return _NotificationTile(item: items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = item;
    final textTheme = Theme.of(context).textTheme;
    final unread = !notification.isRead;
    return Card(
      color: unread ? AppColors.primaryContainer.withValues(alpha: 0.10) : AppColors.surfaceContainer,
      child: ListTile(
        onTap: unread
            ? () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(notificationsControllerProvider.notifier).markRead(notification.id);
                } on ApiException catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.neon.withValues(alpha: 0.16),
          child: Icon(
            _iconFor(notification.type),
            size: 20,
            color: unread ? AppColors.neon : AppColors.onSurfaceVariant,
          ),
        ),
        title: Text(
          notification.title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body.isNotEmpty)
              Text(notification.body, style: textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d · h:mm a').format(notification.createdAt.toLocal()),
              style: textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        trailing: unread
            ? const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.circle, size: 10, color: AppColors.neon),
              )
            : null,
      ),
    );
  }

  static IconData _iconFor(String type) {
    return switch (type) {
      'like' => Icons.favorite,
      'comment' => Icons.chat_bubble_outline,
      'follow' => Icons.person_add_alt,
      'rsvp' => Icons.event_available,
      'review' => Icons.rate_review,
      'report' => Icons.flag,
      'system' => Icons.campaign,
      'ticket' => Icons.confirmation_number,
      _ => Icons.notifications,
    };
  }
}
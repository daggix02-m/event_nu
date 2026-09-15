import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/status_chip.dart';
import '../discovery/data/event.dart';
import '../discovery/discovery_providers.dart';
import 'organizer_chip.dart';
import 'venue_preview.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error is ApiException ? error.message : 'Could not load this event.',
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (event) => _EventDetailBody(event: event),
      ),
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        if (event.posterUrl != null)
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: event.posterUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(color: AppColors.surfaceContainerHigh),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 15, color: AppColors.neon),
                    const SizedBox(width: 6),
                    Text(event.whenLabel, style: textTheme.bodyMedium),
                    const SizedBox(width: 16),
                    StatusChip(label: event.priceLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OrganizerChip(organizerId: event.organizerId),
                    const Spacer(),
                    if (event.likeCount > 0)
                      StatusChip(label: '${event.likeCount} likes', icon: Icons.favorite, color: AppColors.neon),
                  ],
                ),
                const SizedBox(height: 20),
                if (event.venueId != null) ...[
                  Text('Venue', style: textTheme.titleSmall?.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  VenuePreview(venueId: event.venueId!),
                  const SizedBox(height: 20),
                ],
                Text('About', style: textTheme.titleSmall?.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text(
                  event.description.isEmpty ? 'No description provided.' : event.description,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppColors.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_outlined, color: AppColors.neon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Likes, comments and saves arrive in the social phase.',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
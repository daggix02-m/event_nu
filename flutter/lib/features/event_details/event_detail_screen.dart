import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/status_chip.dart';
import '../discovery/data/event.dart';
import '../discovery/discovery_providers.dart';
import '../engagement/widgets/report_sheet.dart';
import '../engagement/widgets/review_section.dart';
import '../engagement/widgets/rsvp_button.dart';
import '../moments/share_moment_sheet.dart';
import '../social/widgets/comment_section.dart';
import '../social/widgets/social_action_row.dart';
import '../tickets/widgets/checkout_sheet.dart';
import 'organizer_chip.dart';
import 'venue_preview.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
            onPressed: () => showReportSheet(
              context,
              entityType: 'event',
              entityId: eventId,
              subject: 'This event',
            ),
          ),
        ],
      ),
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
                Row(
                  children: [
                    if (event.actionType.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () => showCheckoutSheet(context, event.id),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Tickets'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => context.go('/events/${event.id}/gallery'),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => ShareMomentSheet(eventId: event.id),
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Share'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RsvpButton(eventId: event.id),
                const SizedBox(height: 16),
                SocialActionRow(
                  eventId: event.id,
                  initialLiked: event.likedByMe,
                  initialLikeCount: event.likeCount,
                  initialSaved: event.savedByMe,
                ),
                const SizedBox(height: 28),
                CommentSection(eventId: event.id),
                const SizedBox(height: 32),
                ReviewSection(eventId: event.id),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import '../discovery/data/venue.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/widgets/event_card.dart';

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(venueDetailProvider(venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Venue')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error is ApiException ? error.message : 'Could not load this venue.',
          onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
        ),
        data: (detail) => _VenueBody(detail: detail),
      ),
    );
  }
}

class _VenueBody extends StatelessWidget {
  const _VenueBody({required this.detail});

  final VenueDetail detail;

  Future<void> _openMaps(BuildContext context) async {
    final venue = detail.venue;
    final uri = venue.hasCoordinates
        ? Uri.parse('geo:${venue.latitude},${venue.longitude}?q=${Uri.encodeComponent(venue.address)}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${venue.name} ${venue.address}')}');
    final launched = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for this venue.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final venue = detail.venue;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.neon.withValues(alpha: 0.16),
              child: const Icon(Icons.place, color: AppColors.neon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: textTheme.headlineSmall),
                  Text(
                    [venue.address, venue.city].where((s) => s.isNotEmpty).join(' · '),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => _openMaps(context),
          icon: const Icon(Icons.directions),
          label: Text('Open in Maps — ${venue.hasCoordinates ? 'coordinates' : venue.name}'),
        ),
        if (detail.events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.event_busy,
              title: 'No upcoming events',
              message: 'This venue has no events to show right now.',
            ),
          )
        else ...[
          const SizedBox(height: 20),
          Text(
            'Upcoming events · ${detail.eventsTotal}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...detail.events.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventCard(event: event),
              )),
        ],
      ],
    );
  }
}
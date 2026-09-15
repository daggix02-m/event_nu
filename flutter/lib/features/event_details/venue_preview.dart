import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/status_chip.dart';
import '../discovery/data/venue.dart';
import '../discovery/discovery_providers.dart';

/// Compact venue card shown on the event detail screen.
class VenuePreview extends ConsumerWidget {
  const VenuePreview({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(venueDetailProvider(venueId));
    return value.when(
      loading: () => const _VenueSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (detail) => _VenueCard(detail: detail),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.detail});

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
    final venue = detail.venue;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: AppColors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: AppColors.neon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(venue.name, style: textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              venue.address.isNotEmpty ? venue.address : venue.city,
              style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusChip(
                  label: '${detail.events.length} event${detail.events.length == 1 ? '' : 's'} here',
                  color: AppColors.tertiary,
                  icon: Icons.event,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _openMaps(context),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueSkeleton extends StatelessWidget {
  const _VenueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceContainer,
      child: SizedBox(
        height: 96,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
          ),
        ),
      ),
    );
  }
}
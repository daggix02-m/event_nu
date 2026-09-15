import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import 'data/moment_models.dart';
import 'moment_providers.dart';

class EventGalleryScreen extends ConsumerWidget {
  const EventGalleryScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(eventMomentsControllerProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: value.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error is ApiException
              ? error.message
              : 'Could not load the gallery.',
          onRetry: () => ref.invalidate(eventMomentsControllerProvider(eventId)),
        ),
        data: (moments) {
          if (moments.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No moments yet',
              message: 'Photos shared by attendees will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(eventMomentsControllerProvider(eventId).future),
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: moments.length + 1,
              itemBuilder: (context, index) {
                if (index == moments.length) {
                  return _GridFooter(eventId: eventId);
                }
                return _MomentTile(moment: moments[index], eventId: eventId);
              },
            ),
          );
        },
      ),
    );
  }
}

class _GridFooter extends ConsumerStatefulWidget {
  const _GridFooter({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_GridFooter> createState() => _GridFooterState();
}

class _GridFooterState extends ConsumerState<_GridFooter> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ref.read(eventMomentsControllerProvider(widget.eventId).notifier);
    if (!_requested && controller.hasMore) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(eventMomentsControllerProvider(widget.eventId).notifier).loadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(eventMomentsControllerProvider(widget.eventId).notifier);
    if (!controller.hasMore) return const SizedBox.shrink();
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _MomentTile extends ConsumerWidget {
  const _MomentTile({required this.moment, required this.eventId});

  final Moment moment;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaAssetProvider(moment.mediaAssetId));
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: _fullImage(media.value?.displayUrl),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridTile(
          child: _photo(url: media.value?.displayUrl, ready: media.value?.isReady ?? false),
        ),
      ),
    );
  }

  Widget _photo({String? url, required bool ready}) {
    if ((url == null || url.isEmpty) || !ready) {
      return const ColoredBox(
        color: AppColors.surfaceContainer,
        child: Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceVariant),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(
        color: AppColors.surfaceContainer,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceContainer,
        child: Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _fullImage(String? url) {
    if ((url == null || url.isEmpty)) {
      return const Text('Image unavailable', style: TextStyle(color: Colors.white));
    }
    return InteractiveViewer(
      child: Center(
        child: Image.network(
          url,
          errorBuilder: (_, _, _) => const Text(
            'Image unavailable',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
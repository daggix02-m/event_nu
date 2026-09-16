import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../discovery/data/event.dart';
import '../../../shared/widgets/event_nu_logo.dart';

/// Full-bleed hero for the home feed.
///
/// When a [featured] event exists it reads as a cinematic poster card:
/// full-width media with a top-to-bottom gradient and the event headline,
/// time and price overlaid at the bottom. When the feed is empty (or still
/// loading) it falls back to a brand moment so the page never feels dead.
class HeroMarquee extends StatelessWidget {
  const HeroMarquee({super.key, required this.featured, this.categoryName});

  final Event? featured;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final event = featured;
    return event == null ? _BrandHero() : _EventHero(event: event, categoryName: categoryName);
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event, this.categoryName});

  final Event event;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: const ValueKey('home-hero'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(AppRoute.event(event.id)),
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _media(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.45, 1],
                    colors: [
                      Color(0x33141217),
                      Colors.transparent,
                      Color(0xF0141217),
                    ],
                  ),
                ),
              ),
              if (categoryName != null)
                Positioned(
                  top: AppSpace.md,
                  left: AppSpace.md,
                  child: _Chip(label: categoryName!),
                ),
              Positioned(
                left: AppSpace.md,
                right: AppSpace.md,
                bottom: AppSpace.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt,
                          size: 16,
                          color: AppColors.neon,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.whenLabel,
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.neon,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        _Chip(label: event.priceLabel),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _media() {
    final url = event.posterUrl ?? event.teaserUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const _HeroFallbackArt(),
      );
    }
    return const _HeroFallbackArt();
  }
}

class _HeroFallbackArt extends StatelessWidget {
  const _HeroFallbackArt();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceContainerHigh, AppColors.primaryContainer],
        ),
      ),
      child: Center(
        child: EventNuLogo.mark(width: 64, color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB33B383E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x4719E3FF)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('home-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.marginMobile,
        AppSpace.xl,
        AppSpace.marginMobile,
        AppSpace.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryContainer, AppColors.neon, Color(0x55141217)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find yourz', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Addis is calling',
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Events, venues and moments from the city underground — '
            'everything on one Radar.',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
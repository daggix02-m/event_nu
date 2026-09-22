import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../discovery/data/event.dart';
import '../../home/widgets/hero_marquee.dart';

/// Auto-advancing featured event carousel with progress bars, swipe, and
/// tap zones. Falls back to the static [HeroMarquee] when fewer than two
/// events have a poster or teaser image.
///
/// Matches the web app's `FeaturedCarousel` behavior:
/// - 3-second auto-advance (pauses on touch/swipe)
/// - Per-slide animated progress fill
/// - Left/right tap zones (1/3 screen width each)
/// - Category + price + date overlay chips
/// - Pause/play toggle
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.events});

  /// Candidate events. The carousel picks those with a poster or teaser.
  final List<Event> events;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late final PageController _pageController;
  Timer? _advanceTimer;
  int _currentIndex = 0;
  bool _isPaused = false;

  static const _advanceDuration = Duration(seconds: 3);

  List<Event> get _carouselEvents =>
      widget.events.where((e) => e.posterUrl != null || e.teaserUrl != null).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _advanceTimer?.cancel();
    if (_carouselEvents.length <= 1 || _isPaused) return;
    _advanceTimer = Timer.periodic(_advanceDuration, (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _carouselEvents.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _goToSlide(int index) {
    final count = _carouselEvents.length;
    if (count <= 1) return;
    final target = ((index % count) + count) % count;
    if (target == _currentIndex) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Left/right tap zones: the outer thirds of the carousel step between
  /// featured events (mirrors the web app's quick click-to-change zones).
  void _onTapUp(TapUpDetails details) {
    final count = _carouselEvents.length;
    if (count <= 1) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final dx = details.localPosition.dx;
    if (dx < width / 3) {
      _goToSlide(_currentIndex - 1);
    } else if (dx > width * 2 / 3) {
      _goToSlide(_currentIndex + 1);
    }
  }

  void _onPanDown() {
    _isPaused = true;
    _advanceTimer?.cancel();
  }

  void _onPanUp() {
    _isPaused = false;
    _startAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _carouselEvents;

    // Fallback: fewer than two candidates → render the static hero.
    if (candidates.length < 2) {
      final featured = candidates.isNotEmpty ? candidates.first : null;
      return HeroMarquee(featured: featured);
    }

    return GestureDetector(
      onPanDown: (_) => _onPanDown(),
      onPanEnd: (_) => _onPanUp(),
      onPanCancel: _onPanUp,
      onTapUp: _onTapUp,
      child: SizedBox(
        height: 360,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Page view
            PageView.builder(
              controller: _pageController,
              itemCount: candidates.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _Slide(event: candidates[index]);
              },
            ),

            // Gradient overlay (bottom-to-top)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 1],
                  colors: [
                    Color(0x33141217),
                    Colors.transparent,
                    Color(0xF0141217),
                  ],
                ),
              ),
            ),

            // Category chip (top-left)
            if (candidates[_currentIndex].categoryId != null)
              Positioned(
                top: AppSpace.md,
                left: AppSpace.md,
                child: _CarouselChip(
                  label: _categoryLabel(candidates[_currentIndex]),
                ),
              ),

            // ENDED chip (top-left, after category)
            if (_isEventPast(candidates[_currentIndex]))
              Positioned(
                top: AppSpace.md,
                left: candidates[_currentIndex].categoryId != null ? 80 : AppSpace.md,
                child: const _CarouselChip(
                  label: 'ENDED',
                  color: AppColors.error,
                ),
              ),

            // Bottom content: date + title + price
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
                      const Icon(Icons.bolt, size: 16, color: AppColors.neon),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          candidates[_currentIndex].whenLabel,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.neon,
                                letterSpacing: 0.4,
                              ),
                        ),
                      ),
                      _CarouselChip(label: candidates[_currentIndex].priceLabel),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    candidates[_currentIndex].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            // Progress dots (bottom-center)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: _ProgressDots(
                count: candidates.length,
                currentIndex: _currentIndex,
                isPaused: _isPaused,
                advanceDuration: _advanceDuration,
                onTap: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(Event event) {
    // Use the event's title as a rough category proxy until the category
    // name is resolved by the parent (which already has categoryNames map).
    return event.title.length > 12 ? '${event.title.substring(0, 11)}…' : event.title;
  }

  bool _isEventPast(Event event) {
    if (event.endsAt != null) {
      return event.endsAt!.isBefore(DateTime.now());
    }
    return event.startsAt.isBefore(DateTime.now());
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final url = event.posterUrl ?? event.teaserUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const _SlideFallback(),
      );
    }
    return const _SlideFallback();
  }
}

class _SlideFallback extends StatelessWidget {
  const _SlideFallback();

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
    );
  }
}

class _CarouselChip extends StatelessWidget {
  const _CarouselChip({required this.label, this.color});

  final String label;
  final Color? color;

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
              color: color ?? AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ProgressDots extends StatefulWidget {
  const _ProgressDots({
    required this.count,
    required this.currentIndex,
    required this.isPaused,
    required this.advanceDuration,
    required this.onTap,
  });

  final int count;
  final int currentIndex;
  final bool isPaused;
  final Duration advanceDuration;
  final ValueChanged<int> onTap;

  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _fillController;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      duration: widget.advanceDuration,
      vsync: this,
    );
    _fillController.forward();
  }

  @override
  void didUpdateWidget(covariant _ProgressDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _fillController
        ..reset()
        ..forward();
    }
    if (widget.isPaused && !oldWidget.isPaused) {
      _fillController.stop();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      _fillController.forward();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (index) {
        final isActive = index == widget.currentIndex;
        return GestureDetector(
          onTap: () => widget.onTap(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 32 : 24,
            height: 4,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            child: isActive
                ? AnimatedBuilder(
                    animation: _fillController,
                    builder: (context, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _fillController.value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }),
    );
  }
}

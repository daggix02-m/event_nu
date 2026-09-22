import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_space.dart';
import '../../discovery/data/category.dart';
import '../../discovery/data/event.dart';
import '../../discovery/discovery_providers.dart';
import 'category_shelf.dart';

/// Renders per-category horizontal event shelves above the flat feed.
///
/// Fetches the first [maxCategories] top-level categories in parallel, then
/// fetches up to [eventsPerCategory] events per category. Shelves are hidden
/// during loading (no visual jump); errors in one category don't block others.
///
/// Matches the web app's `CategoryEventShelf` section rendered on the
/// Discover home page.
class CategoryShelfSection extends ConsumerWidget {
  const CategoryShelfSection({
    super.key,
    this.maxCategories = 6,
    this.eventsPerCategory = 8,
  });

  final int maxCategories;
  final int eventsPerCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesValue = ref.watch(categoriesProvider);

    return categoriesValue.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        final top = categories.take(maxCategories).toList();
        return _ShelfList(
          categories: top,
          eventsPerCategory: eventsPerCategory,
        );
      },
    );
  }
}

class _ShelfList extends ConsumerStatefulWidget {
  const _ShelfList({
    required this.categories,
    required this.eventsPerCategory,
  });

  final List<Category> categories;
  final int eventsPerCategory;

  @override
  ConsumerState<_ShelfList> createState() => _ShelfListState();
}

class _ShelfListState extends ConsumerState<_ShelfList> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in widget.categories)
          _CategoryShelfSlot(
            key: ValueKey(category.id),
            category: category,
            eventsPerCategory: widget.eventsPerCategory,
          ),
      ],
    );
  }
}

class _CategoryShelfSlot extends ConsumerWidget {
  const _CategoryShelfSlot({
    super.key,
    required this.category,
    required this.eventsPerCategory,
  });

  final Category category;
  final int eventsPerCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelfProvider = _categoryEventsProvider(
      _CategoryEventsKey(category.id, eventsPerCategory),
    );
    final value = ref.watch(shelfProvider);

    return value.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: CategoryShelf(
            category: category,
            events: events,
            onSeeAll: () =>
                ref.read(feedControllerProvider.notifier).setCategory(category.id),
          ),
        );
      },
    );
  }
}

/// Cache key combining category ID + limit to avoid refetching when
/// the same params are requested.
class _CategoryEventsKey {
  const _CategoryEventsKey(this.categoryId, this.limit);
  final String categoryId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CategoryEventsKey &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(categoryId, limit);
}

/// Per-category event list provider. Uses the existing
/// `DiscoveryRepository.listEvents` with the category filter.
final _categoryEventsProvider =
    FutureProvider.family<List<Event>, _CategoryEventsKey>((ref, key) async {
  final repo = ref.read(discoveryRepositoryProvider);
  try {
    final page = await repo.listEvents(
      categoryId: key.categoryId,
      limit: key.limit,
    );
    return page.items;
  } on ApiException catch (e) {
    if (e.code == 'network_error') return const <Event>[];
    return const <Event>[];
  } catch (_) {
    return const <Event>[];
  }
});

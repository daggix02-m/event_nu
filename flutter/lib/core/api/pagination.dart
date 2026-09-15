import '../ext/json_utils.dart';

class Paginated<T> {
  const Paginated({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasNext,
    required this.items,
  });

  final int page;
  final int limit;
  final int total;
  final bool hasNext;
  final List<T> items;

  static Paginated<T> fromJson<T>(
    Map<String, dynamic> body, {
    required T Function(Map<String, dynamic>) parseItem,
  }) {
    final pagination = body.object('pagination') ?? const <String, dynamic>{};
    final data = body['data'];
    final items = switch (data) {
      List<dynamic> list => list
          .whereType<Map<String, dynamic>>()
          .map(parseItem)
          .toList(growable: false),
      _ => <T>[],
    };
    return Paginated<T>(
      page: pagination.intOr('page', 1),
      limit: pagination.intOr('limit', items.length),
      total: pagination.intOr('total', items.length),
      hasNext: pagination.boolOr('has_next', false),
      items: items,
    );
  }
}
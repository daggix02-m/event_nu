class SyncChange {
  const SyncChange({
    required this.domain,
    required this.op,
    required this.id,
    this.payload,
  });

  final String domain;
  final String op;
  final String id;
  final Map<String, dynamic>? payload;

  bool get isDelete => op == 'delete';

  factory SyncChange.fromJson(Map<String, dynamic> json) => SyncChange(
        domain: json['domain'] as String,
        op: json['op'] as String,
        id: json['id'] as String,
        payload: json['payload'] is Map<String, dynamic>
            ? json['payload'] as Map<String, dynamic>
            : null,
      );

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'op': op,
        'id': id,
        if (payload != null) 'payload': payload,
      };
}

class SyncData {
  const SyncData({
    required this.changes,
    required this.nextCursor,
    this.hasMore = const {},
  });

  final List<SyncChange> changes;
  final String nextCursor;
  final Map<String, bool> hasMore;

  factory SyncData.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List<dynamic>? ?? const [];
    final rawMore = json['has_more'] as Map<String, dynamic>?;
    return SyncData(
      changes: rawChanges
          .map((e) => SyncChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
      hasMore: rawMore?.map((k, v) => MapEntry(k, v == true)) ?? const {},
    );
  }
}

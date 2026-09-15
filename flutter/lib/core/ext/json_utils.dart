extension JsonMapX on Map<String, dynamic> {
  String? str(String key) => this[key] is String ? this[key] as String : null;

  String strOr(String key, String fallback) {
    final v = this[key];
    return v is String && v.isNotEmpty ? v : fallback;
  }

  int? integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int intOr(String key, int fallback) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  double? decimal(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    return null;
  }

  bool boolOr(String key, [bool fallback = false]) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  DateTime? date(String key) {
    final v = this[key];
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic>? object(String key) {
    final v = this[key];
    return v is Map<String, dynamic> ? v : null;
  }
}
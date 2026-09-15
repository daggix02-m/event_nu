import '../../../core/ext/json_utils.dart';

class UploadIntent {
  const UploadIntent({
    required this.id,
    required this.kind,
    required this.status,
    required this.uploadUrl,
    required this.uploadExpirySeconds,
  });

  final String id;
  final String kind;
  final String status;
  final String uploadUrl;
  final int uploadExpirySeconds;

  factory UploadIntent.fromJson(Map<String, dynamic> json) => UploadIntent(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        status: json['status'] as String? ?? '',
        uploadUrl: json['upload_url'] as String? ?? '',
        uploadExpirySeconds: json.intOr('upload_expiry_seconds', 0),
      );
}

class MediaVariant {
  const MediaVariant({
    required this.variant,
    required this.url,
    this.density,
    this.width,
    this.height,
  });

  final String variant;
  final String url;
  final String? density;
  final int? width;
  final int? height;

  factory MediaVariant.fromJson(Map<String, dynamic> json) => MediaVariant(
        variant: json.strOr('variant', ''),
        url: json.strOr('url', ''),
        density: json.str('density'),
        width: json.integer('width'),
        height: json.integer('height'),
      );
}

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.status,
    required this.variants,
    this.contentType,
    this.errorMessage,
  });

  final String id;
  final String kind;
  final String status;
  final String? contentType;
  final String? errorMessage;
  final List<MediaVariant> variants;

  bool get isReady => status == 'ready' || status == 'processed';

  String? get displayUrl {
    MediaVariant? best;
    String? bestDensity;
    for (final v in variants) {
      final density = _densityRank(v.density) ?? 3;
      final rank = bestDensity == null ? -1 : _densityRank(bestDensity) ?? 3;
      if (density > rank) {
        best = v;
        bestDensity = v.density;
      }
    }
    return best?.url;
  }

  static int? _densityRank(String? density) => switch (density) {
        '1x' => 1,
        '2x' => 2,
        '3x' => 3,
        _ => null,
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        status: json['status'] as String? ?? '',
        contentType: json.str('content_type'),
        errorMessage: json.str('error_message'),
        variants: (json['variants'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MediaVariant.fromJson)
            .toList(),
      );
}

class Moment {
  const Moment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.mediaAssetId,
    required this.createdAt,
    this.caption = '',
  });

  final String id;
  final String eventId;
  final String userId;
  final String mediaAssetId;
  final String caption;
  final DateTime createdAt;

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String,
        mediaAssetId: json['media_asset_id'] as String,
        caption: json.strOr('caption', ''),
        createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
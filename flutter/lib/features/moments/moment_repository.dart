import 'dart:math';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/pagination.dart';
import 'data/moment_models.dart';

String _newIdempotencyKey() {
  final rng = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(28, (_) => chars[rng.nextInt(chars.length)]).join();
}

class MomentRepository {
  MomentRepository(this._api);

  final ApiClient _api;

  Future<UploadIntent> createUploadIntent({
    required String kind,
    required String contentType,
    required int sizeBytes,
  }) async {
    final data = await _api.post(
      '/api/v1/media/upload-intents',
      data: <String, dynamic>{
        'kind': kind,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      },
      idempotencyKey: _newIdempotencyKey(),
    );
    return UploadIntent.fromJson(data as Map<String, dynamic>);
  }

  Future<MediaAsset> completeUpload(String mediaId) async {
    final data = await _api.post('/api/v1/media/$mediaId/complete');
    return MediaAsset.fromJson(data as Map<String, dynamic>);
  }

  Future<MediaAsset> media(String mediaId) async {
    final data = await _api.get('/api/v1/media/$mediaId');
    return MediaAsset.fromJson(data as Map<String, dynamic>);
  }

  Future<Moment> shareMoment(
    String eventId, {
    required String mediaAssetId,
    required String caption,
  }) async {
    final data = await _api.post(
      '/api/v1/events/$eventId/moments',
      data: <String, dynamic>{'media_asset_id': mediaAssetId, 'caption': caption},
      idempotencyKey: _newIdempotencyKey(),
    );
    return Moment.fromJson(data as Map<String, dynamic>);
  }

  Future<Paginated<Moment>> eventMoments(String eventId, {int page = 1, int limit = 30}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/events/$eventId/moments',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: Moment.fromJson);
  }

  /// Uploads raw bytes to the presigned URL. `idempotencyKey` is provided by
  /// callers that re-upload a failed attempt with the same key.
  Future<void> uploadToPresigned(String url, List<int> bytes, String contentType) async {
    await Dio().put<dynamic>(
      url,
      data: bytes,
      options: Options(
        headers: <String, dynamic>{'Content-Type': contentType},
      ),
    );
  }
}
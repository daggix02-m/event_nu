import '../../core/api/api_client.dart';
import '../../core/api/pagination.dart';
import 'data/category.dart';
import 'data/event.dart';
import 'data/organizer.dart';
import 'data/venue.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> listCategories() async {
    final envelope = await _api.getEnvelope('/api/v1/categories');
    final data = envelope['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
    }
    return const [];
  }

  Future<Paginated<Event>> listEvents({
    String? query,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (categoryId != null) params['category'] = categoryId;
    if (dateFrom != null) params['date_from'] = dateFrom.toUtc().toIso8601String();
    if (dateTo != null) params['date_to'] = dateTo.toUtc().toIso8601String();
    final envelope = await _api.getEnvelope('/api/v1/events', queryParameters: params);
    return Paginated.fromJson(envelope, parseItem: Event.fromJson);
  }

  Future<Event> getEvent(String id) async {
    return Event.fromJson(await _api.get('/api/v1/events/$id'));
  }

  Future<Paginated<Venue>> listVenues({int page = 1, int limit = 20}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/venues',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: Venue.fromJson);
  }

  Future<VenueDetail> getVenue(String id) async {
    return VenueDetail.fromJson(await _api.get('/api/v1/venues/$id'));
  }

  Future<Organizer> getOrganizer(String id) async {
    return Organizer.fromJson(await _api.get('/api/v1/organizers/$id'));
  }
}
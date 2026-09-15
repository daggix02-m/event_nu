import '../../../core/ext/json_utils.dart';
import 'event.dart';

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.city,
    this.countryCode,
    required this.status,
  });

  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String city;
  final String? countryCode;
  final String status;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json.strOr('id', ''),
      name: json.strOr('name', ''),
      address: json.strOr('address', ''),
      latitude: json.decimal('latitude'),
      longitude: json.decimal('longitude'),
      city: json.strOr('city', ''),
      countryCode: json.str('country_code'),
      status: json.strOr('status', ''),
    );
  }
}

class VenueDetail {
  const VenueDetail({
    required this.venue,
    required this.events,
    required this.eventsTotal,
    required this.eventsPage,
    required this.eventsPageSize,
    required this.eventsHasNextPage,
  });

  final Venue venue;
  final List<Event> events;
  final int eventsTotal;
  final int eventsPage;
  final int eventsPageSize;
  final bool eventsHasNextPage;

  factory VenueDetail.fromJson(Map<String, dynamic> json) {
    final venue = json.object('venue');
    final events = json['events'];
    return VenueDetail(
      venue: venue == null ? const Venue(id: '', name: '', address: '', city: '', status: '') : Venue.fromJson(venue),
      events: switch (events) {
        List<dynamic> list => list.whereType<Map<String, dynamic>>().map(Event.fromJson).toList(growable: false),
        _ => const [],
      },
      eventsTotal: json.intOr('events_total', 0),
      eventsPage: json.intOr('events_page', 1),
      eventsPageSize: json.intOr('events_page_size', 0),
      eventsHasNextPage: json.boolOr('events_has_next_page', false),
    );
  }
}
import '../../core/api/api_client.dart';
import 'data/ticket_models.dart';

class TicketRepository {
  TicketRepository(this._api);

  final ApiClient _api;

  Future<List<TicketType>> listTicketTypes(String eventId) async {
    final data = await _api.get('/api/v1/events/$eventId/ticket-types');
    final list = data is List ? data : const [];
    return list.whereType<Map<String, dynamic>>().map(TicketType.fromJson).toList();
  }

  Future<OrderResult> createOrder(String eventId, List<(String, int)> items) async {
    final data = await _api.post(
      '/api/v1/events/$eventId/orders',
      data: <String, dynamic>{
        'items': [
          for (final (ticketTypeId, quantity) in items)
            {'ticket_type_id': ticketTypeId, 'quantity': quantity},
        ],
      },
    );
    return OrderResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TicketItem>> myTickets() async {
    final data = await _api.get('/api/v1/me/tickets');
    final list = data is List ? data : const [];
    return list.whereType<Map<String, dynamic>>().map(TicketItem.fromJson).toList();
  }
}
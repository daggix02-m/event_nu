import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/ticket_models.dart';
import 'ticket_repository.dart';

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref.watch(apiClientProvider));
});

/// Public ticket tiers for one event; drives the checkout sheet.
final ticketTypesControllerProvider =
    AsyncNotifierProvider.family<TicketTypesController, List<TicketType>, String>(
  TicketTypesController.new,
);

class TicketTypesController extends AsyncNotifier<List<TicketType>> {
  TicketTypesController(this.eventId);

  final String eventId;

  TicketRepository get _repo => ref.read(ticketRepositoryProvider);

  @override
  Future<List<TicketType>> build() async {
    final types = List<TicketType>.of(await _repo.listTicketTypes(eventId));
    return types..sort((a, b) => a.priceMinor.compareTo(b.priceMinor));
  }
}

/// The current user's issued tickets.
final myTicketsControllerProvider =
    AsyncNotifierProvider<MyTicketsController, List<TicketItem>>(MyTicketsController.new);

class MyTicketsController extends AsyncNotifier<List<TicketItem>> {
  TicketRepository get _repo => ref.read(ticketRepositoryProvider);

  @override
  Future<List<TicketItem>> build() async => _repo.myTickets();
}
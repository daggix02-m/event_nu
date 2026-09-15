import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/features/tickets/data/ticket_models.dart';
import 'package:event_nu/features/tickets/ticket_providers.dart';
import 'package:event_nu/features/tickets/ticket_repository.dart';
import 'package:event_nu/features/tickets/widgets/checkout_sheet.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getEnvelope(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data}) async => throw UnimplementedError();
}

class FakeTicketRepository extends TicketRepository {
  FakeTicketRepository() : super(_UnusedApiClient());

  @override
  Future<List<TicketType>> listTicketTypes(String eventId) async => const [];
}

Widget _wrap(Widget child, FakeTicketRepository repo) => ProviderScope(
      overrides: [ticketRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('ticket model parsing', () {
    test('TicketType.isFree, canBuy, and priceLabel', () {
      final free = TicketType.fromJson(const {
        'id': 't-1',
        'event_id': 'e-1',
        'name': 'General',
        'price_minor': 0,
        'currency': 'ETB',
        'quantity_sold': 10,
        'is_active': true,
        'sold_out': false,
        'sales_open': true,
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      });
      expect(free.isFree, isTrue);
      expect(free.priceLabel, 'Free');
      expect(free.canBuy, isTrue);

      final soldOut = TicketType.fromJson(const {
        'id': 't-2',
        'event_id': 'e-1',
        'name': 'VIP',
        'price_minor': 10000,
        'currency': 'ETB',
        'quantity_sold': 50,
        'quantity_total': 50,
        'is_active': true,
        'sold_out': true,
        'sales_open': false,
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      });
      expect(soldOut.isFree, isFalse);
      expect(soldOut.soldOut, isTrue);
      expect(soldOut.canBuy, isFalse);
    });

    test('TicketQr.payload is valid JSON', () {
      final qr = TicketQr.fromJson(const {
        'ticket_id': 'tk-1',
        'event_id': 'e-1',
        'issued_at': '2026-10-01T09:00:00Z',
        'hmac': 'abc123',
      });
      expect(qr.payload, contains('"ticket_id":"tk-1"'));
      expect(qr.payload, contains('"hmac":"abc123"'));
    });

    test('OrderResult.needsPaymentRedirect', () {
      final withPayment = OrderResult.fromJson(const {
        'id': 'o-1',
        'event_id': 'e-1',
        'status': 'pending_payment',
        'currency': 'ETB',
        'subtotal_minor': 1000,
        'total_minor': 1000,
        'payment': {
          'provider': 'telebirr',
          'provider_ref': 'ref-1',
          'redirect_url': 'https://pay.test/redirect',
        },
      });
      expect(withPayment.needsPaymentRedirect, isTrue);
      expect(withPayment.payment?.redirectUrl, 'https://pay.test/redirect');

      final noPayment = OrderResult.fromJson(const {
        'id': 'o-2',
        'event_id': 'e-1',
        'status': 'confirmed',
        'currency': 'ETB',
        'subtotal_minor': 0,
        'total_minor': 0,
      });
      expect(noPayment.needsPaymentRedirect, isFalse);
      expect(noPayment.payment, isNull);
    });
  });

  group('checkout sheet', () {
    testWidgets('shows empty state when no tiers', (tester) async {
      await tester.pumpWidget(_wrap(const CheckoutSheet(eventId: 'e-1'), FakeTicketRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('No tickets on sale for this event.'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}
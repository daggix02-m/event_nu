import '../../../core/ext/json_utils.dart';

class TicketType {
  const TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.priceMinor,
    required this.currency,
    this.quantityTotal,
    required this.quantitySold,
    this.salesStart,
    this.salesEnd,
    required this.isActive,
    required this.soldOut,
    required this.salesOpen,
  });

  final String id;
  final String eventId;
  final String name;
  final String? description;
  final int priceMinor;
  final String currency;
  final int? quantityTotal;
  final int quantitySold;
  final DateTime? salesStart;
  final DateTime? salesEnd;
  final bool isActive;
  final bool soldOut;
  final bool salesOpen;

  bool get isFree => priceMinor == 0;

  /// Human price label, e.g. "Free" or "500 ETB".
  String get priceLabel => isFree
      ? 'Free'
      : '${_formatMinor(priceMinor)} ${currency.toUpperCase()}';

  bool get canBuy => isActive && salesOpen && !soldOut;

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json.strOr('id', ''),
      eventId: json.strOr('event_id', ''),
      name: json.strOr('name', ''),
      description: json.str('description'),
      priceMinor: json.integer('price_minor') ?? 0,
      currency: json.strOr('currency', 'ETB'),
      quantityTotal: json.integer('quantity_total'),
      quantitySold: json.integer('quantity_sold') ?? 0,
      salesStart: json.date('sales_start'),
      salesEnd: json.date('sales_end'),
      isActive: json.boolOr('is_active', true),
      soldOut: json.boolOr('sold_out', false),
      salesOpen: json.boolOr('sales_open', true),
    );
  }

  static String _formatMinor(int minor) {
    final major = minor / 100;
    final text = major == major.roundToDouble() ? major.toStringAsFixed(0) : major.toStringAsFixed(2);
    return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}

/// A ticket this user was issued; QR carries the signed check-in payload.
class TicketItem {
  const TicketItem({
    required this.id,
    required this.orderItemId,
    required this.eventId,
    required this.ticketTypeId,
    required this.status,
    required this.issuedAt,
    this.usedAt,
    required this.qr,
  });

  final String id;
  final String orderItemId;
  final String eventId;
  final String ticketTypeId;
  final String status;
  final DateTime issuedAt;
  final DateTime? usedAt;
  final TicketQr qr;

  bool get isUsed => usedAt != null;

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    return TicketItem(
      id: json.strOr('id', ''),
      orderItemId: json.strOr('order_item_id', ''),
      eventId: json.strOr('event_id', ''),
      ticketTypeId: json.strOr('ticket_type_id', ''),
      status: json.strOr('status', ''),
      issuedAt: json.date('issued_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      usedAt: json.date('used_at'),
      qr: TicketQr.fromJson(json.object('qr') ?? const {}),
    );
  }
}

class TicketQr {
  const TicketQr({required this.ticketId, required this.eventId, required this.issuedAt, required this.hmac});

  final String ticketId;
  final String eventId;
  final String issuedAt;
  final String hmac;

  /// The exact string an attendee QR encodes; the venue decodes this packet.
  String get payload => '{"ticket_id":"$ticketId","event_id":"$eventId","issued_at":"$issuedAt","hmac":"$hmac"}';

  factory TicketQr.fromJson(Map<String, dynamic> json) {
    return TicketQr(
      ticketId: json.strOr('ticket_id', ''),
      eventId: json.strOr('event_id', ''),
      issuedAt: json.strOr('issued_at', ''),
      hmac: json.strOr('hmac', ''),
    );
  }
}

/// Order placed at checkout; `payment.redirectUrl` is set when a provider
/// needs the buyer to finish paying off-app.
class OrderResult {
  const OrderResult({
    required this.id,
    required this.eventId,
    required this.status,
    required this.currency,
    required this.subtotalMinor,
    required this.totalMinor,
    this.payment,
  });

  final String id;
  final String eventId;
  final String status;
  final String currency;
  final int subtotalMinor;
  final int totalMinor;
  final PaymentInit? payment;

  bool get needsPaymentRedirect => payment?.redirectUrl != null && payment!.redirectUrl!.isNotEmpty;

  factory OrderResult.fromJson(Map<String, dynamic> json) {
    final payment = json.object('payment');
    return OrderResult(
      id: json.strOr('id', ''),
      eventId: json.strOr('event_id', ''),
      status: json.strOr('status', ''),
      currency: json.strOr('currency', 'ETB'),
      subtotalMinor: json.integer('subtotal_minor') ?? 0,
      totalMinor: json.integer('total_minor') ?? 0,
      payment: payment == null ? null : PaymentInit.fromJson(payment),
    );
  }
}

class PaymentInit {
  const PaymentInit({required this.provider, required this.providerRef, this.redirectUrl});

  final String provider;
  final String providerRef;
  final String? redirectUrl;

  factory PaymentInit.fromJson(Map<String, dynamic> json) {
    return PaymentInit(
      provider: json.strOr('provider', ''),
      providerRef: json.strOr('provider_ref', ''),
      redirectUrl: json.str('redirect_url'),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../data/ticket_models.dart';
import '../ticket_providers.dart';

/// Bottom sheet that lists ticket tiers and drives the order checkout.
Future<void> showCheckoutSheet(BuildContext context, String eventId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerHigh,
    builder: (_) => CheckoutSheet(eventId: eventId),
  );
}

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final _quantities = <String, int>{};
  bool _placing = false;

  int get _totalMinor {
    var total = 0;
    for (final entry in _quantities.entries) {
      final count = entry.value;
      if (count == 0) continue;
      total += count * (ref
              .read(ticketTypesControllerProvider(widget.eventId))
              .value
              ?.firstWhere((t) => t.id == entry.key)
              .priceMinor ??
          0);
    }
    return total;
  }

  int get _totalCount => _quantities.values.fold(0, (sum, q) => sum + q);

  bool get _canPlace => _totalCount > 0 && !_placing;

  Future<void> _placeOrder() async {
    setState(() => _placing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final items = <(String, int)>[
        for (final entry in _quantities.entries)
          if (entry.value > 0) (entry.key, entry.value),
      ];
      final order = await ref.read(ticketRepositoryProvider).createOrder(widget.eventId, items);
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(myTicketsControllerProvider);
      if (order.needsPaymentRedirect) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Finish payment in the page that just opened.')),
        );
        await launchUrl(Uri.parse(order.payment!.redirectUrl!));
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Your tickets are confirmed — check My Tickets.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not place your order. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(ticketTypesControllerProvider(widget.eventId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pad = MediaQuery.of(context).padding;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg + bottomInset + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: value.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
                  ),
                ),
              ),
              error: (error, _) => Text(
                error is ApiException ? error.message : 'Tickets could not load.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              data: (types) {
                if (types.isEmpty) {
                  return Text(
                    'No tickets on sale for this event.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [for (final tier in types) _TierRow(tier: tier, quantity: _quantityFor(tier.id), onChanged: (q) => _setQuantity(tier.id, q))],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_totalCount ticket${_totalCount == 1 ? '' : 's'} · ${_formatMinor(_totalMinor)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton(
                onPressed: _canPlace ? _placeOrder : null,
                child: _placing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get tickets'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _quantityFor(String id) => _quantities[id] ?? 0;

  void _setQuantity(String id, int q) {
    setState(() {
      if (q == 0) {
        _quantities.remove(id);
      } else {
        _quantities[id] = q;
      }
    });
  }

  static String _formatMinor(int minor) {
    final major = minor / 100;
    final text = major == major.roundToDouble() ? major.toStringAsFixed(0) : major.toStringAsFixed(2);
    return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.quantity, required this.onChanged});

  final TicketType tier;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canBuy = tier.canBuy;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: textTheme.titleSmall?.copyWith(
                    color: canBuy ? AppColors.onSurface : AppColors.onSurfaceVariant,
                  ),
                ),
                if (tier.description != null && tier.description!.isNotEmpty)
                  Text(tier.description!, style: textTheme.bodySmall),
                Text(
                  canBuy ? tier.priceLabel : (tier.soldOut ? 'Sold out' : 'Not on sale'),
                  style: textTheme.labelMedium?.copyWith(color: AppColors.neon),
                ),
              ],
            ),
          ),
          if (canBuy)
            Row(
              children: [
                IconButton(
                  onPressed: quantity == 0 ? null : () => onChanged(quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                ),
                Text('$quantity', style: textTheme.titleSmall),
                IconButton(
                  onPressed: () => onChanged(quantity + 1),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                ),
              ],
            )
          else
            Icon(Icons.lock_outline, size: 18, color: AppColors.onSurfaceVariant),
        ],
      ),
    );
  }
}
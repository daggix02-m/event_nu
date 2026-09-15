import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import 'data/ticket_models.dart';
import 'ticket_providers.dart';

class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myTicketsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: value.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error is ApiException ? error.message : 'Could not load your tickets.',
          onRetry: () => ref.invalidate(myTicketsControllerProvider),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const EmptyState(
              icon: Icons.confirmation_number,
              title: 'No tickets yet',
              message: 'Buy a ticket from an event to see your code here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myTicketsControllerProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.sm),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _TicketCard(ticket: tickets[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.ticket});

  final TicketItem ticket;

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ticket = widget.ticket;
    return Card(
      color: AppColors.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.neon.withValues(alpha: 0.16),
                    child: Icon(
                      ticket.isUsed ? Icons.check_circle : Icons.confirmation_number,
                      color: ticket.isUsed ? AppColors.tertiary : AppColors.neon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.isUsed ? 'Used' : 'Active',
                          style: textTheme.titleSmall?.copyWith(
                            color: ticket.isUsed ? AppColors.onSurfaceVariant : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Ticket ${ticket.id.split('-').first}',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        if (!ticket.isUsed)
                          Text(
                            'Issued ${DateFormat('MMM d').format(ticket.issuedAt.toLocal())}',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: ticket.qr.payload,
                      version: QrVersions.auto,
                      size: 180,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Show this code at the door',
                    style: textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
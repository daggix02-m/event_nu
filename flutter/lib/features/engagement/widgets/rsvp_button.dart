import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../engagement_providers.dart';

/// Full-width go / not-going toggle for the event detail header.
class RsvpButton extends ConsumerWidget {
  const RsvpButton({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(rsvpControllerProvider(eventId));
    return switch (value) {
      AsyncData(:final value) => FilledButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(rsvpControllerProvider(eventId).notifier).toggle();
            } on ApiException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
          icon: Icon(value?.going == true
              ? Icons.check_circle
              : Icons.event_available_outlined),
          label: Text(value?.going == true ? 'You are going' : "I'm going"),
        ),
      AsyncError(:final error) => FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error is ApiException ? error.message : 'Could not load RSVP state.')),
          ),
          icon: const Icon(Icons.error_outline),
          label: const Text('RSVP unavailable'),
        ),
      _ => const FilledButton(onPressed: null, child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
    };
  }
}
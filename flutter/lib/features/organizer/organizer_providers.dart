import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

import 'organizer_controller.dart';
import 'organizer_repository.dart';

final organizerRepositoryProvider = Provider<OrganizerRepository>((ref) {
  return OrganizerRepository(ref.watch(apiClientProvider));
});

final organizerWizardControllerProvider =
    NotifierProvider<OrganizerWizardController, OrganizerWizardState>(
  OrganizerWizardController.new,
);
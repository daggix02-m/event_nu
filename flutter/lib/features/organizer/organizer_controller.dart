import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../shared/validation/form_errors.dart';
import '../../shared/validation/validators.dart';

import 'data/organizer_application.dart';
import 'organizer_providers.dart';

/// Draft of the organizer wizard: only the fields the backend accepts
/// (`requested_name`, optional `requested_slug`, optional `bio`) plus the
/// current wizard [step].
class OrganizerApplicationDraft {
  const OrganizerApplicationDraft({
    this.requestedName = '',
    this.requestedSlug = '',
    this.requestedBio = '',
    this.step = 0,
  });

  final String requestedName;
  final String requestedSlug;
  final String requestedBio;
  final int step;

  OrganizerApplicationDraft copyWith({
    String? requestedName,
    String? requestedSlug,
    String? requestedBio,
    int? step,
  }) {
    return OrganizerApplicationDraft(
      requestedName: requestedName ?? this.requestedName,
      requestedSlug: requestedSlug ?? this.requestedSlug,
      requestedBio: requestedBio ?? this.requestedBio,
      step: step ?? this.step,
    );
  }
}

class OrganizerWizardState {
  const OrganizerWizardState({
    required this.draft,
    this.submitting = false,
    this.application,
    this.errors,
    this.loaded = false,
  });

  final OrganizerApplicationDraft draft;
  final bool submitting;

  /// Set once an application exists (submitted or loaded from the backend).
  final OrganizerApplication? application;

  final FieldErrors? errors;

  /// Whether an initial `GET /organizer-applications/me` lookup has finished.
  final bool loaded;
}

/// Holds the organizer wizard draft, runs field validation and orchestrates
/// the submission while sticking to backend-accepted fields.
class OrganizerWizardController extends Notifier<OrganizerWizardState> {
  @override
  OrganizerWizardState build() {
    return const OrganizerWizardState(draft: OrganizerApplicationDraft());
  }

  String get name => state.draft.requestedName.trim();
  String get slug => state.draft.requestedSlug.trim();
  String get bio => state.draft.requestedBio.trim();

  /// The handle the backend will assign: the requested slug when provided,
  /// otherwise the slugified organization name.
  String get previewSlug {
    final source = slug.isNotEmpty ? slug : name;
    return slugify(source);
  }

  String? validateName([String? value]) => validateRequiredText(
        value ?? state.draft.requestedName,
        label: 'Organization name',
        min: 3,
        max: 80,
      );

  String? validateSlug([String? value]) => validateOptionalMax(
        value ?? state.draft.requestedSlug,
        label: 'Handle',
        max: 60,
      );

  String? validateBio([String? value]) => validateOptionalMax(
        value ?? state.draft.requestedBio,
        label: 'Bio',
        max: 2000,
      );

  bool get canProceedStep0 => validateName() == null && validateSlug() == null;

  void setName(String value) => _update(
        draft: state.draft.copyWith(requestedName: value),
        errors: null,
      );

  void setSlug(String value) => _update(
        draft: state.draft.copyWith(requestedSlug: value),
        errors: null,
      );

  void setBio(String value) => _update(
        draft: state.draft.copyWith(requestedBio: value),
        errors: null,
      );

  void next() {
    if (state.draft.step >= 1) return;
    if (state.draft.step == 0 && !canProceedStep0) return;
    _update(draft: state.draft.copyWith(step: 1), errors: null);
  }

  void back() {
    if (state.draft.step == 0) return;
    _update(draft: state.draft.copyWith(step: state.draft.step - 1));
  }

  Future<bool> submit() async {
    if (state.submitting || state.draft.step != 1) return false;
    if (state.application != null) return true;
    _update(submitting: true, errors: null);
    try {
      final application = await ref
          .read(organizerRepositoryProvider)
          .apply(requestedName: name, requestedSlug: slug, bio: bio);
      state = OrganizerWizardState(
        draft: state.draft,
        submitting: false,
        application: application,
        errors: null,
        loaded: true,
      );
      return true;
    } on ApiException catch (e) {
      _update(
        submitting: false,
        errors: mapServerFormError(e, scope: FormScope.organizer),
      );
      return false;
    } catch (_) {
      _update(
        submitting: false,
        errors: const FieldErrors(
          form: 'Something went wrong. Please try again later.',
        ),
      );
      return false;
    }
  }

  /// Loads an existing application when the user revisits this flow.
  /// A 404 simply means they have not applied yet; any other failure keeps the
  /// wizard usable and lets a later submit surface the real server answer.
  Future<void> loadExisting() async {
    if (state.application != null || state.loaded) return;
    try {
      final application =
          await ref.read(organizerRepositoryProvider).getMyApplication();
      state = OrganizerWizardState(
        draft: state.draft,
        submitting: false,
        application: application,
        errors: null,
        loaded: true,
      );
    } on ApiException {
      _update(loaded: true);
    } catch (_) {
      _update(loaded: true);
    }
  }

  /// Clears a previous (e.g. rejected) application so the user can apply again.
  void restart() {
    state = const OrganizerWizardState(
      draft: OrganizerApplicationDraft(),
      loaded: true,
    );
  }

  void _update({
    OrganizerApplicationDraft? draft,
    bool? submitting,
    OrganizerApplication? application,
    FieldErrors? errors,
    bool? loaded,
  }) {
    state = OrganizerWizardState(
      draft: draft ?? state.draft,
      submitting: submitting ?? state.submitting,
      application: application ?? state.application,
      errors: errors,
      loaded: loaded ?? state.loaded,
    );
  }
}
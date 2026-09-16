import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/api_exception.dart';
import 'package:event_nu/features/organizer/data/organizer_application.dart';
import 'package:event_nu/features/organizer/organizer_controller.dart';
import 'package:event_nu/features/organizer/organizer_providers.dart';
import 'package:event_nu/features/organizer/organizer_repository.dart';

class FakeOrganizerRepository extends OrganizerRepository {
  FakeOrganizerRepository() : super(_NoopApiClient());

  ApiException? applyError;
  ApiException? meError;
  OrganizerApplication? existing;

  @override
  Future<OrganizerApplication> apply({
    required String requestedName,
    required String requestedSlug,
    required String bio,
  }) async {
    final error = applyError;
    if (error != null) throw error;
    return _pending(
      requestedName: requestedName,
      // Mirror the backend: firstNonEmpty(requestedSlug, requestedName) then slugify.
      requestedSlug: _slugify(requestedSlug.isNotEmpty ? requestedSlug : requestedName),
      bio: bio,
    );
  }

  String _slugify(String input) {
    final collapsed =
        input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Future<OrganizerApplication> getMyApplication() async {
    final error = meError;
    if (error != null) throw error;
    final app = existing;
    if (app == null) {
      throw const ApiException(
        code: 'not_found',
        message: 'No application found.',
        statusCode: 404,
      );
    }
    return app;
  }

  OrganizerApplication _pending({
    required String requestedName,
    required String requestedSlug,
    required String bio,
  }) {
    return OrganizerApplication(
      id: 'app-1',
      requestedName: requestedName,
      requestedSlug: requestedSlug,
      bio: bio,
      status: 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _NoopApiClient extends ApiClient {
  _NoopApiClient() : super(dio: Dio());
}

void main() {
  group('OrganizerApplication.fromJson', () {
    test('parses the backend payload', () {
      final app = OrganizerApplication.fromJson(const {
        'id': 'app-1',
        'requested_name': 'Addis Collective',
        'requested_slug': 'addis-collective',
        'bio': 'We throw craft nights.',
        'status': 'pending',
        'review_notes': '',
        'created_at': '2026-09-01T00:00:00Z',
      });
      expect(app.requestedName, 'Addis Collective');
      expect(app.requestedSlug, 'addis-collective');
      expect(app.isPending, isTrue);
    });
  });

  late ProviderContainer container;
  late OrganizerWizardController controller;
  late FakeOrganizerRepository repo;

  setUp(() {
    repo = FakeOrganizerRepository();
    container = ProviderContainer(
      overrides: [organizerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    controller = container.read(organizerWizardControllerProvider.notifier);
  });

  test('starts on step 0 with an empty draft', () {
    expect(controller.state.draft.step, 0);
    expect(controller.state.application, isNull);
  });

  test('name validation mirrors the 3-80 character backend rule', () {
    expect(controller.validateName(), isNotNull); // empty
    controller.setName('Hi');
    expect(controller.validateName(), isNotNull);
    controller.setName('a' * 81);
    expect(controller.validateName(), isNotNull);
    controller.setName('Addis Collective');
    expect(controller.validateName(), isNull);
  });

  test('slug and bio are optional but bounded (60 / 2000)', () {
    expect(controller.validateSlug(), isNull);
    expect(controller.validateBio(), isNull);
    controller.setSlug('a' * 61);
    expect(controller.validateSlug(), isNotNull);
    controller.setBio('a' * 2001);
    expect(controller.validateBio(), isNotNull);
  });

  test('preview slug derives from the requested slug, falling back to the name', () {
    controller.setName('Addis Collective');
    expect(controller.previewSlug, 'addis-collective');
    controller.setSlug('  My Big @Org  ');
    expect(controller.previewSlug, 'my-big-org');
  });

  test('submitting on step 1 records the pending application', () async {
    controller.setName('Addis Collective');
    controller.setSlug('');
    controller.setBio('Craft nights.');
    controller.next();
    expect(controller.state.draft.step, 1);

    final ok = await controller.submit();
    expect(ok, isTrue);
    final app = controller.state.application!;
    expect(app.status, 'pending');
    expect(app.requestedName, 'Addis Collective');
    expect(app.requestedSlug, 'addis-collective');
    expect(controller.state.errors, isNull);
  });

  test('409 application_pending surfaces an honest message', () async {
    controller.setName('Addis Collective');
    controller.next();
    repo.applyError = const ApiException(
      code: 'application_pending',
      message: 'You already have a pending organizer application.',
      statusCode: 409,
    );

    final ok = await controller.submit();
    expect(ok, isFalse);
    expect(controller.state.application, isNull);
    expect(controller.state.errors?.form, contains('pending'));
  });

  test('429 submit errors are exposed as rate limited', () async {
    controller.setName('Addis Collective');
    controller.next();
    repo.applyError = const ApiException(
      code: 'too_many_requests',
      message: 'Too many attempts.',
      statusCode: 429,
    );

    final ok = await controller.submit();
    expect(ok, isFalse);
    expect(controller.state.errors?.isRateLimited, isTrue);
  });

  test('loadExisting surfaces an existing pending application', () async {
    repo.existing = OrganizerApplication(
      id: 'app-old',
      requestedName: 'Old Org',
      requestedSlug: 'old-org',
      bio: '',
      status: 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    await controller.loadExisting();
    expect(controller.state.application?.id, 'app-old');
    expect(controller.state.application?.isPending, isTrue);
  });

  test('loadExisting with no application keeps the wizard editable', () async {
    await controller.loadExisting();
    expect(controller.state.application, isNull);
    expect(controller.validateName(), isNotNull); // wizard still available
  });

  test('restart clears the submitted application', () async {
    controller.setName('Addis Collective');
    controller.next();
    await controller.submit();
    controller.restart();
    expect(controller.state.application, isNull);
    expect(controller.state.draft.step, 0);
  });
}
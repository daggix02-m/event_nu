import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../design/app_colors.dart';
import '../../shared/widgets/event_nu_logo.dart';
import '../../shared/widgets/wizard_scaffold.dart';
import 'organizer_controller.dart';
import 'organizer_providers.dart';
import 'data/organizer_application.dart';

class OrganizerApplicationScreen extends ConsumerStatefulWidget {
  const OrganizerApplicationScreen({super.key});

  @override
  ConsumerState<OrganizerApplicationScreen> createState() =>
      _OrganizerApplicationScreenState();
}

class _OrganizerApplicationScreenState
    extends ConsumerState<OrganizerApplicationScreen> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(organizerWizardControllerProvider.notifier).loadExisting();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _syncControllers(OrganizerApplicationDraft draft) {
    if (_nameController.text != draft.requestedName) {
      _nameController.text = draft.requestedName;
    }
    if (_slugController.text != draft.requestedSlug) {
      _slugController.text = draft.requestedSlug;
    }
    if (_bioController.text != draft.requestedBio) {
      _bioController.text = draft.requestedBio;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizerWizardControllerProvider);
    final controller = ref.read(organizerWizardControllerProvider.notifier);
    final application = state.application;
    final step = state.draft.step;

    // Show a spinner while the existing application is being looked up.
    if (application == null && !state.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (application != null) {
      return _StatusView(
        application: application,
        onApplyAgain: controller.restart,
      );
    }

    _syncControllers(state.draft);

    final body = step == 0 ? _detailsStep(controller) : _reviewStep(controller, state);
    final footer = step == 0
        ? _continueFooter(controller)
        : _submitFooter(state, controller);

    return WizardScaffold(
      index: step,
      count: 2,
      title: 'Host in Addis',
      subtitle: step == 0
          ? 'Get your venue on the Addis Radar.'
          : 'Review and send your application.',
      logo: const EventNuLogo.mark(width: 36),
      onBack: step > 0 ? controller.back : null,
      content: body,
      footer: footer,
    );
  }

  Widget _detailsStep(OrganizerWizardController controller) {
    final state = ref.watch(organizerWizardControllerProvider);
    final errors = state.errors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                onChanged: controller.setName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Organization name',
                  hintText: 'e.g. Habesha Collective',
                  helperText: '3–80 characters · how your page is titled.',
                  errorText: errors?.requestedName ?? controller.validateName(),
                ),
                maxLength: 80,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slugController,
                onChanged: controller.setSlug,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Handle',
                  hintText: 'Optional custom handle',
                  helperText: 'eventnu.et/@${controller.previewSlug}',
                  errorText: errors?.requestedSlug,
                  prefixIcon: const Icon(Icons.alternate_email, size: 20),
                ),
                maxLength: 60,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                onChanged: controller.setBio,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'A short tagline or description.',
                  alignLabelWithHint: true,
                  helperText: 'Optional · up to 2000 characters.',
                  errorText: errors?.bio,
                  counterText: '',
                ),
maxLength: 2000,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    final remaining = (maxLength ?? 2000) - currentLength;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$remaining characters remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: remaining > 200
                                ? Theme.of(context).colorScheme.outline
                                : Theme.of(context).colorScheme.error,
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewStep(
      OrganizerWizardController controller, OrganizerWizardState state) {
    final errors = state.errors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'eventnu.et/@${controller.previewSlug}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondary,
                          ),
                    ),
                    if (controller.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.bio,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (errors?.form != null) ...[
                const SizedBox(height: 12),
                Text(
                  errors!.form!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (errors?.requestedName != null) ...[
                const SizedBox(height: 8),
                Text(
                  errors!.requestedName!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _continueFooter(OrganizerWizardController controller) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.canProceedStep0 ? controller.next : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _submitFooter(
      OrganizerWizardState state, OrganizerWizardController controller) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errors?.isRateLimited == true) ...[
                const SizedBox(height: 8),
                Text(
                  'You’re submitting too quickly. Please wait a moment and try again.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  TextButton(
                    onPressed: controller.back,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.submitting ? null : () async => controller.submit(),
                      child: state.submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Apply to host'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.application,
    required this.onApplyAgain,
  });

  final OrganizerApplication application;
  final VoidCallback onApplyAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, title, body, buttonLabel) = switch (application.status) {
      'approved' => (
          Icons.verified,
          'You’re a host',
          'You can now list your venue or event.',
          'Done',
        ),
      'rejected' => (
          Icons.cancel_outlined,
          'Application not approved',
          application.reviewNotes.isNotEmpty
              ? application.reviewNotes
              : 'Your application was not approved at this time.',
          'Apply again',
        ),
      _ => (
          Icons.hourglass_top,
          'Application in review',
          'We’ll review your request and reach out soon.',
          'Done',
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(title, style: textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (application.status == 'rejected') {
                          onApplyAgain();
                        } else {
                          context.go(AppRoute.home.path);
                        }
                      },
                      child: Text(buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
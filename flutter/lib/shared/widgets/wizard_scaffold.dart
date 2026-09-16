import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import 'wizard_step_indicator.dart';

/// Adaptive shell for page-based wizard flows (e.g. the register and
/// organizer-application wizards).
///
/// Keeps the flow readable on wide windows by centering the content in a
/// [maxWidth] column (responsive layout: `Center` + `ConstrainedBox`), while
/// the header, scrollable [content] and sticky [footer] fill the column.
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.index,
    required this.count,
    required this.title,
    this.subtitle,
    required this.content,
    this.footer,
    this.onBack,
    this.logo,
    this.maxWidth = 480,
  });

  /// Zero-based index of the current step.
  final int index;

  /// Total number of steps.
  final int count;

  final String title;
  final String? subtitle;
  final Widget content;
  final Widget? footer;

  /// When provided, a back arrow is shown above the title.
  final VoidCallback? onBack;

  /// Optional brand mark shown at the top of the flow.
  final Widget? logo;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1526), AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.marginMobile,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (logo != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Center(child: logo),
                      const SizedBox(height: AppSpace.md),
                    ],
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackButton(onPressed: onBack),
                      ),
                    if (onBack != null) const SizedBox(height: AppSpace.xs),
                    Text(title, style: textTheme.displayLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        subtitle,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    WizardStepIndicator(index: index, count: count),
                    const SizedBox(height: AppSpace.lg),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: AppSpace.lg),
                        child: content,
                      ),
                    ),
                    ?footer,
                    const SizedBox(height: AppSpace.sm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
    );
  }
}
import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';

/// Segmented progress bar for wizard flows. The current segment glows with the
/// brand neon, completed segments are filled, and future segments are outlined.
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({
    super.key,
    required this.index,
    required this.count,
  });

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.xs),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: i < index
                    ? AppColors.primaryContainer
                    : i == index
                        ? AppColors.neon
                        : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
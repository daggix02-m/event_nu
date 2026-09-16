import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../validation/validators.dart';

/// Four-segment strength meter that reacts to [passwordStrength].
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const _labels = <int, String>{
    0: 'Too weak',
    1: 'Weak',
    2: 'Fair',
    3: 'Good',
    4: 'Strong',
  };

  @override
  Widget build(BuildContext context) {
    final score = passwordStrength(password);
    final labels = _labels;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.x2s),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? _colorFor(score) : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ],
        const SizedBox(width: AppSpace.sm),
        Text(
          labels[score]!,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: score < 2
                    ? AppColors.onSurfaceVariant
                    : _colorFor(score),
              ),
        ),
      ],
    );
  }

  Color _colorFor(int score) {
    if (score <= 1) return AppColors.error;
    if (score == 2) return const Color(0xFFFFC86B);
    return AppColors.neon;
  }
}
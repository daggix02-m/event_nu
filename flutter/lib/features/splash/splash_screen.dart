import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/event_nu_logo.dart';

/// Branded launch screen shown while the session is restored for the first
/// time. The router redirects away as soon as [SessionController.bootstrapped]
/// flips to true, so this screen contains no navigation of its own.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [Color(0xFF2A2040), AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EventNuLogo(width: 160),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Find yourz.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColors.neon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
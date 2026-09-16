import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_space.dart';

/// Minimal map shell — the venue map is still warming up on the Radar.
class CityMapScreen extends StatelessWidget {
  const CityMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('City map')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 44,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('The city, mapped', style: textTheme.headlineMedium),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Venues around Addis Ababa are appearing on the map. '
                  'Check back soon.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass surface (Level 1–3 in the design system).
///
/// Uses an inner [BackdropFilter] blur over a translucent [tint] with an
/// ambient [borderColor] stroke and optional violet [shadow]. Radius defaults
/// to the fully-pill shape used by nav bars and chips.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.blur = 24,
    this.tint = const Color(0xE018141E),
    this.borderColor = const Color(0x4719E3FF),
    this.radius = 9999,
    this.shadow,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final double blur;
  final Color tint;
  final Color borderColor;
  final double radius;
  final BoxShadow? shadow;
  final EdgeInsetsGeometry padding;

  /// When provided the card is tappable (with an ink ripple).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(this.radius);
    final decoration = BoxDecoration(
      color: tint,
      borderRadius: radius,
      border: Border.all(color: borderColor),
      boxShadow: shadow == null ? null : <BoxShadow>[shadow!],
    );

    final surface = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: onTap == null
            ? surface
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: surface),
              ),
      ),
    );
  }
}
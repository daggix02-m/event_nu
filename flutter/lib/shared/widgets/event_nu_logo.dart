import 'package:flutter/material.dart';

import '../../design/app_colors.dart';

/// Renders the Event Nu brand.
///
/// - [EventNuLogo] (default): the wordmark lockup, ideal for splash screens,
///   sign-in headers, and width-limited spots.
/// - [EventNuLogo.mark]: the square badge, ideal for compact app bars and
///   placeholder marks.
///
/// A [color] tint is applied with [BlendMode.srcIn], which preserves the
/// alpha channel while recolouring the artwork.
class EventNuLogo extends StatelessWidget {
  const EventNuLogo({
    super.key,
    this.width = 132,
    this.height,
    this.color,
  }) : _asset = _lockupAsset;

  const EventNuLogo.mark({
    super.key,
    this.width = 40,
    this.height,
    this.color,
  }) : _asset = _markAsset;

  static const String _lockupAsset = 'assets/brand/logo.png';
  static const String _markAsset = 'assets/brand/mark.webp';

  // Native aspect ratio of the source PNG (794 x 672).
  static const double _lockupAspectRatio = 794 / 672;

  final double width;
  final double? height;
  final Color? color;
  final String _asset;

  bool get _isMark => _asset == _markAsset;

  @override
  Widget build(BuildContext context) {
    final boxHeight =
        height ?? (_isMark ? width : width / _lockupAspectRatio);

    final image = Image.asset(
      _asset,
      width: width,
      height: boxHeight,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: boxHeight,
        child: Icon(
          Icons.bolt,
          color: color ?? AppColors.neon,
          size: boxHeight > width ? width : null,
        ),
      ),
      semanticLabel: 'Event Nu',
    );

    return ExcludeSemantics(
      excluding: false,
      child: image,
    );
  }
}
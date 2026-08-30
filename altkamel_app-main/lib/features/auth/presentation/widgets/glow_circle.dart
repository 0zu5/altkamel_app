import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A soft, blurred color blob used to decorate gradient panels — mirrors the
/// glow blobs behind the branding panel on the altkamel-website login page.
class GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const GlowCircle({
    super.key,
    required this.color,
    required this.size,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

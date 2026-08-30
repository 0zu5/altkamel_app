import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A white, rounded, softly-shadowed container used throughout the portal
/// tabs — the mobile equivalent of the website's white cards on a slate
/// background.
class PortalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PortalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    // The white fill + rounded corners are drawn by an inner `Material`
    // (rather than a plain DecoratedBox) so that any ListTile/InkWell
    // inside `child` finds a proper Material ancestor for its background
    // and ink splashes instead of painting them invisibly behind this
    // card's own decoration.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A section title used above a group of cards ("الرصيد", "الباقة الحالية"...).
class PortalSectionTitle extends StatelessWidget {
  final String title;

  const PortalSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: AppColors.slate900,
        ),
      ),
    );
  }
}

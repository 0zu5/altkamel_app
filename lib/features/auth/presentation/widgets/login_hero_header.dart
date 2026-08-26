import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'glow_circle.dart';

/// The gradient "brand" header at the top of the login screen: logo,
/// headline and a short pitch, matching the dark navy → indigo gradient
/// panel from the website's `/portal/login` page.
///
/// Bleeds behind the status bar (its height includes [topInset]) so the
/// gradient reaches the very top of the screen instead of leaving a gap.
class LoginHeroHeader extends StatelessWidget {
  final double topInset;

  const LoginHeroHeader({super.key, required this.topInset});

  static const double _contentHeight = 300;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: SizedBox(
        height: _contentHeight + topInset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.hero),
            ),
            const Positioned(
              top: -40,
              right: -20,
              child: GlowCircle(color: AppColors.indigo, size: 170),
            ),
            const Positioned(
              bottom: -40,
              left: -30,
              child: GlowCircle(color: AppColors.cyan, size: 160),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 24 + topInset, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    // Use decoration to handle both background color and smooth borders
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDD0), // Cream background color
                      borderRadius: BorderRadius.circular(
                        12.0,
                      ), // Smooths the borders (adjust radius as needed)
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 56,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(height: 56),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تطبيق التكامل نت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'إدارة متكاملة لحسابك وباقات الإنترنت في مكان واحد بأمان تام.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

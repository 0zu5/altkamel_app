import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Minimal placeholder shown right after a successful login.
///
/// Replace this with the real dashboard (mirrors the website's
/// `/portal/dashboard` page) once it's ready.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: AppGradients.button,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'تم تسجيل الدخول بنجاح',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'لوحة التحكم قيد الإنشاء حالياً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

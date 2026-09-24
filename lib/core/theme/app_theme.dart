import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors pulled from the altkamel-website Tailwind config / login
/// page, so the app matches the site's look and feel.
class AppColors {
  AppColors._();

  // brand.purple.600 / login button gradient start
  static const indigo = Color(0xFF6366F1);
  // login button gradient end (sky-500)
  static const cyan = Color(0xFF0EA5E9);

  // Hero panel gradient stops (website: #0B0F24 -> #1A235A -> #2B32B2)
  static const heroStart = Color(0xFF0B0F24);
  static const heroMid = Color(0xFF1A235A);
  static const heroEnd = Color(0xFF2B32B2);

  static const slateBg = Color(0xFFF8FAFC); // slate-50
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate100 = Color(0xFFF1F5F9);

  static const rose50 = Color(0xFFFFF1F2);
  static const rose200 = Color(0xFFFECDD3);
  static const rose700 = Color(0xFFBE123C);
}

class AppGradients {
  AppGradients._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.heroStart, AppColors.heroMid, AppColors.heroEnd],
    stops: [0.0, 0.55, 1.0],
  );

  static const button = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.indigo, AppColors.cyan],
  );
}

enum AppThemeToken { altkamelDefault, altkamelNight }

AppThemeToken appThemeTokenFromId(String? value) {
  return switch (value) {
    'altkamel-night' => AppThemeToken.altkamelNight,
    _ => AppThemeToken.altkamelDefault,
  };
}

/// Theme selection is intentionally bounded to tokens compiled into this
/// application. Server configuration can select a token; it cannot provide
/// arbitrary styling or executable UI.
ThemeData buildAppTheme({AppThemeToken token = AppThemeToken.altkamelDefault}) {
  final night = token == AppThemeToken.altkamelNight;
  final background = night ? const Color(0xFF0F172A) : AppColors.slateBg;
  final seed = night ? const Color(0xFF818CF8) : AppColors.indigo;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      brightness: night ? Brightness.dark : Brightness.light,
      seedColor: seed,
      primary: seed,
      secondary: AppColors.cyan,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: GoogleFonts.cairo().fontFamily,
    textTheme: GoogleFonts.cairoTextTheme(),
  );

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.slate100,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.slate100, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.slate100, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.indigo, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.rose200, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.slate700,
        fontWeight: FontWeight.w900,
      ),
      hintStyle: const TextStyle(color: AppColors.slate400),
    ),
  );
}

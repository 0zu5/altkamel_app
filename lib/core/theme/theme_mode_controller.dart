import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a customer-owned visual preference on the device. The server may
/// choose a bundled brand palette, but it never forces a light/dark mode.
class ThemeModeController extends ChangeNotifier {
  static const _storageKey = 'mobile_theme_mode';

  final FlutterSecureStorage storage;
  ThemeMode mode = ThemeMode.light;

  ThemeModeController({required this.storage});

  Future<void> load() async {
    mode = (await storage.read(key: _storageKey)) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDark(bool enabled) async {
    mode = enabled ? ThemeMode.dark : ThemeMode.light;
    await storage.write(key: _storageKey, value: enabled ? 'dark' : 'light');
    notifyListeners();
  }
}

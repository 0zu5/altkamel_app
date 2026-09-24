import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'app_config_repository.dart';

class AppConfigController extends ChangeNotifier {
  final AppConfigRepository repository;
  MobileAppConfig config = MobileAppConfig.fallback;

  AppConfigController({required this.repository});

  Future<void> loadCached() async {
    final cached = await repository.loadCached();
    if (cached == null) return;
    config = cached;
    notifyListeners();
  }

  /// A failed refresh intentionally leaves the currently known-good cache in
  /// place. The app remains usable with its bundled fallback while offline.
  Future<void> refresh() async {
    try {
      config = await repository.fetch();
      notifyListeners();
    } catch (_) {
      // Safe fallback / cached config is already active.
    }
  }
}

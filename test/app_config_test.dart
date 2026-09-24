import 'package:altkamel_app/core/app_config/app_config.dart';
import 'package:altkamel_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the default token for an unknown server theme', () {
    final config = MobileAppConfig.fromJson({
      'version': 2,
      'theme': {'id': 'untrusted-remote-theme'},
      'min_supported_version': '1.0.0',
      'latest_version': '1.0.0',
    });

    expect(config.theme, AppThemeToken.altkamelDefault);
  });

  test('maps an allowlisted night token and ignores invalid versions', () {
    final config = MobileAppConfig.fromJson({
      'version': '5',
      'theme': {'id': 'altkamel-night'},
      'min_supported_version': 'not-a-version',
      'latest_version': '1.2.0',
    });

    expect(config.version, 5);
    expect(config.theme, AppThemeToken.altkamelNight);
    expect(config.minSupportedVersion, '1.0.0');
    expect(config.latestVersion, '1.2.0');
  });
}

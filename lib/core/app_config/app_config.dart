import '../theme/app_theme.dart';

class MobileAppConfig {
  final int version;
  final AppThemeToken theme;
  final String minSupportedVersion;
  final String latestVersion;
  final String? maintenanceMessage;

  const MobileAppConfig({
    required this.version,
    required this.theme,
    required this.minSupportedVersion,
    required this.latestVersion,
    this.maintenanceMessage,
  });

  static const fallback = MobileAppConfig(
    version: 0,
    theme: AppThemeToken.altkamelDefault,
    minSupportedVersion: '1.0.0',
    latestVersion: '1.0.0',
  );

  factory MobileAppConfig.fromJson(Map<String, dynamic> json) {
    final theme = json['theme'];
    final maintenance = json['maintenance'];
    return MobileAppConfig(
      version: _asInt(json['version']),
      theme: appThemeTokenFromId(theme is Map ? theme['id']?.toString() : null),
      minSupportedVersion: _versionOrFallback(json['min_supported_version']),
      latestVersion: _versionOrFallback(json['latest_version']),
      maintenanceMessage: maintenance is Map && maintenance['message'] is String
          ? maintenance['message'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'theme': {
      'id': switch (theme) {
        AppThemeToken.altkamelDefault => 'altkamel-default',
        AppThemeToken.altkamelNight => 'altkamel-night',
      },
    },
    'min_supported_version': minSupportedVersion,
    'latest_version': latestVersion,
    'maintenance': maintenanceMessage == null
        ? null
        : {'message': maintenanceMessage},
  };
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _versionOrFallback(Object? value) {
  final string = value?.toString() ?? '';
  return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(string)
      ? string
      : MobileAppConfig.fallback.minSupportedVersion;
}

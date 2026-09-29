import '../theme/app_theme.dart';

class MobileAppConfig {
  final int version;
  final AppThemeToken theme;
  final String minSupportedVersion;
  final String latestVersion;
  final String? maintenanceMessage;
  final List<HomeBanner> banners;

  const MobileAppConfig({
    required this.version,
    required this.theme,
    required this.minSupportedVersion,
    required this.latestVersion,
    this.maintenanceMessage,
    this.banners = const [],
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
      banners: (json['banners'] is List ? json['banners'] as List : const [])
          .whereType<Map>()
          .map((banner) => HomeBanner.fromJson(banner))
          .where((banner) => banner.imageUrl != null)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'theme': {
      'id': switch (theme) {
        AppThemeToken.altkamelDefault => 'altkamel-default',
        AppThemeToken.altkamelNight => 'altkamel-night',
        AppThemeToken.altkamelOcean => 'altkamel-ocean',
        AppThemeToken.altkamelSand => 'altkamel-sand',
        AppThemeToken.altkamelRose => 'altkamel-rose',
      },
    },
    'min_supported_version': minSupportedVersion,
    'latest_version': latestVersion,
    'maintenance': maintenanceMessage == null
        ? null
        : {'message': maintenanceMessage},
    'banners': banners.map((banner) => banner.toJson()).toList(),
  };
}

class HomeBanner {
  final String? title;
  final Uri? imageUrl;
  final Uri? actionUrl;

  const HomeBanner({this.title, this.imageUrl, this.actionUrl});

  factory HomeBanner.fromJson(Map json) => HomeBanner(
    title: json['title']?.toString(),
    imageUrl: _httpsUri(json['image_url']),
    actionUrl: _httpsUri(json['action_url']),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'image_url': imageUrl?.toString(),
    'action_url': actionUrl?.toString(),
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

Uri? _httpsUri(Object? value) {
  final uri = Uri.tryParse(value?.toString() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri
      : null;
}

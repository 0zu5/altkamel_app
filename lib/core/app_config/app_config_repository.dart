import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import 'app_config.dart';

class AppConfigRepository {
  static const _cacheKey = 'mobile_app_config_v1';

  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  AppConfigRepository({required this.apiClient, required this.storage});

  Future<MobileAppConfig?> loadCached() async {
    final raw = await storage.read(key: _cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? MobileAppConfig.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<MobileAppConfig> fetch() async {
    final response = await apiClient.dio.get('/app-config');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) throw const FormatException('Invalid app configuration.');
    final config = MobileAppConfig.fromJson(Map<String, dynamic>.from(data));
    await storage.write(key: _cacheKey, value: jsonEncode(config.toJson()));
    return config;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores only the customer's opt-in preference. The access and refresh
/// tokens remain in platform-backed secure storage; this service asks the OS
/// to verify the device owner before the saved session is opened.
class BiometricLoginService {
  static const _enabledKey = 'biometric_login_enabled';

  final FlutterSecureStorage storage;
  final LocalAuthentication _localAuth;

  BiometricLoginService({required this.storage, LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isEnabled() async =>
      (await storage.read(key: _enabledKey)) == 'true';

  Future<bool> enable() async {
    if (!await _canUseBiometrics()) return false;

    final authenticated = await _localAuth.authenticate(
      localizedReason: 'أكد هويتك لتفعيل الدخول بالبصمة إلى حساب التكامل.',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
    if (authenticated) {
      await storage.write(key: _enabledKey, value: 'true');
    }
    return authenticated;
  }

  Future<void> disable() => storage.delete(key: _enabledKey);

  Future<bool> unlock() async {
    if (!await _canUseBiometrics()) return false;
    return _localAuth.authenticate(
      localizedReason: 'أكد هويتك لفتح حساب التكامل.',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<bool> _canUseBiometrics() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      if (!await _localAuth.canCheckBiometrics) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }
}

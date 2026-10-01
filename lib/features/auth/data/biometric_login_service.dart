import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricLoginException implements Exception {
  final String message;
  const BiometricLoginException(this.message);
}

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
    await _ensureAvailable();

    final authenticated = await _authenticate(
      'أكد هويتك لتفعيل الدخول بالبصمة إلى حساب التكامل.',
    );
    if (authenticated) {
      await storage.write(key: _enabledKey, value: 'true');
    }
    return authenticated;
  }

  Future<void> disable() => storage.delete(key: _enabledKey);

  Future<bool> unlock() async {
    await _ensureAvailable();
    return _authenticate('أكد هويتك لفتح حساب التكامل.');
  }

  Future<void> _ensureAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        throw const BiometricLoginException(
          'هذا الجهاز لا يدعم تسجيل الدخول بالبصمة.',
        );
      }
      // Some Android OEM biometric services report an empty enrolled-types
      // list even when a fingerprint is configured. Do not reject that device
      // before calling the platform prompt; the prompt is the authority.
      if (!await _localAuth.canCheckBiometrics) {
        throw const BiometricLoginException(
          'لم يتم إعداد بصمة أو Face ID في إعدادات الجهاز.',
        );
      }
    } on LocalAuthException catch (error) {
      throw BiometricLoginException(_messageFor(error));
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      throw BiometricLoginException(_messageFor(error));
    }
  }

  String _messageFor(LocalAuthException error) => switch (error.code) {
    LocalAuthExceptionCode.noCredentialsSet ||
    LocalAuthExceptionCode.noBiometricsEnrolled =>
      'لم يتم إعداد بصمة أو Face ID في إعدادات الجهاز.',
    LocalAuthExceptionCode.noBiometricHardware =>
      'هذا الجهاز لا يحتوي على مستشعر بصمة أو Face ID.',
    LocalAuthExceptionCode.biometricLockout ||
    LocalAuthExceptionCode.temporaryLockout =>
      'تم قفل البصمة مؤقتاً. افتح الجهاز أولاً ثم حاول مرة أخرى.',
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled => 'تم إلغاء التحقق بالبصمة.',
    _ => 'تعذر استخدام البصمة حالياً. ${error.description ?? ''}'.trim(),
  };
}

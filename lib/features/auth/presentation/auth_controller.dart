import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  bool isLoading = false;
  String? errorMessage;

  AuthController({required this.repository});

  Future<bool> login(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final success = await repository.login(username, password);
      if (!success) {
        errorMessage = 'بيانات الدخول غير صحيحة';
      }
      return success;
    } catch (e, stackTrace) {
      debugPrint('=== LOGIN ERROR ===');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      final message = e.toString().replaceFirst('Exception: ', '').trim();
      // Never surface a blank error banner — always fall back to something
      // readable if the underlying message ended up empty.
      errorMessage = message.isNotEmpty
          ? message
          : 'حدث خطأ غير متوقع، حاول مرة أخرى.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await repository.logout();
    errorMessage = null;
    notifyListeners();
  }
}

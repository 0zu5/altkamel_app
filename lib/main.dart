import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/app_config/app_config_controller.dart';
import 'core/app_config/app_config_repository.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/biometric_login_service.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/portal/data/portal_repository.dart';
import 'features/portal/presentation/portal_controller.dart';
import 'features/portal/presentation/portal_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android is configured with the checked-in google-services.json. iOS is
  // deliberately postponed until its APNs/Firebase enrollment is available.
  if (Platform.isAndroid) {
    await Firebase.initializeApp();
  }

  // Initialize Core Dependencies
  const storage = FlutterSecureStorage();
  final apiClient = ApiClient(storage: storage);
  final appConfigRepository = AppConfigRepository(
    apiClient: apiClient,
    storage: storage,
  );
  final appConfigController = AppConfigController(
    repository: appConfigRepository,
  );
  final themeModeController = ThemeModeController(storage: storage);

  // Initialize Auth Dependencies
  final authRepository = AuthRepository(apiClient: apiClient, storage: storage);
  final authController = AuthController(repository: authRepository);
  final biometricLoginService = BiometricLoginService(storage: storage);

  // Initialize Portal Dependencies (dashboard/packages/invoices/account)
  final portalRepository = PortalRepository(apiClient: apiClient);

  runApp(
    MyApp(
      authController: authController,
      authRepository: authRepository,
      biometricLoginService: biometricLoginService,
      portalRepository: portalRepository,
      appConfigController: appConfigController,
      themeModeController: themeModeController,
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthController authController;
  final AuthRepository authRepository;
  final BiometricLoginService biometricLoginService;
  final PortalRepository portalRepository;
  final AppConfigController appConfigController;
  final ThemeModeController themeModeController;

  const MyApp({
    super.key,
    required this.authController,
    required this.authRepository,
    required this.biometricLoginService,
    required this.portalRepository,
    required this.appConfigController,
    required this.themeModeController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Keep portal state above MaterialApp. Theme changes rebuild MaterialApp,
  // and some Android devices recreate the home route during that rebuild.
  // The loaded account must survive either behavior.
  late final PortalController _portalController = PortalController(
    repository: widget.portalRepository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(widget.appConfigController.loadCached());
    unawaited(widget.themeModeController.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.appConfigController,
        widget.themeModeController,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'بوابة التكامل نت',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(token: widget.appConfigController.config.theme),
        darkTheme: buildAppTheme(
          token: widget.appConfigController.config.theme,
          brightness: Brightness.dark,
        ),
        themeMode: widget.themeModeController.mode,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: _SessionGate(
          authController: widget.authController,
          authRepository: widget.authRepository,
          biometricLoginService: widget.biometricLoginService,
          portalRepository: widget.portalRepository,
          portalController: _portalController,
          appConfigController: widget.appConfigController,
          themeModeController: widget.themeModeController,
        ),
      ),
    );
  }
}

/// Skips straight to the portal if a session token is already stored —
/// mirrors the website's login page redirecting an already-authenticated
/// visitor straight to `/portal/dashboard`.
class _SessionGate extends StatefulWidget {
  final AuthController authController;
  final AuthRepository authRepository;
  final BiometricLoginService biometricLoginService;
  final PortalRepository portalRepository;
  final PortalController portalController;
  final AppConfigController appConfigController;
  final ThemeModeController themeModeController;

  const _SessionGate({
    required this.authController,
    required this.authRepository,
    required this.biometricLoginService,
    required this.portalRepository,
    required this.portalController,
    required this.appConfigController,
    required this.themeModeController,
  });

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<bool> _isAuthenticated = widget.authRepository
      .isAuthenticated();
  bool _refreshedConfig = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAuthenticated,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return FutureBuilder<bool>(
            future: widget.biometricLoginService.isEnabled(),
            builder: (context, biometricSnapshot) {
              if (biometricSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (biometricSnapshot.data == true) {
                return LoginScreen(
                  authController: widget.authController,
                  portalRepository: widget.portalRepository,
                  appConfigController: widget.appConfigController,
                  themeModeController: widget.themeModeController,
                  biometricLoginService: widget.biometricLoginService,
                  biometricUnlockAvailable: true,
                );
              }
              return _buildPortal();
            },
          );
        }
        return LoginScreen(
          authController: widget.authController,
          portalRepository: widget.portalRepository,
          appConfigController: widget.appConfigController,
          themeModeController: widget.themeModeController,
          biometricLoginService: widget.biometricLoginService,
        );
      },
    );
  }

  Widget _buildPortal() {
    if (!_refreshedConfig) {
      _refreshedConfig = true;
      unawaited(widget.appConfigController.refresh());
    }
    return PortalShell(
      controller: widget.portalController,
      authController: widget.authController,
      appConfigController: widget.appConfigController,
      themeModeController: widget.themeModeController,
      biometricLoginService: widget.biometricLoginService,
    );
  }
}

class _BiometricLockScreen extends StatefulWidget {
  final BiometricLoginService service;
  final VoidCallback onUnlocked;

  const _BiometricLockScreen({required this.service, required this.onUnlocked});

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _unlock() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (await widget.service.unlock()) {
        widget.onUnlocked();
        return;
      }
      if (mounted) {
        setState(() => _error = 'لم يتم التحقق من البصمة. حاول مرة أخرى.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر استخدام البصمة على هذا الجهاز.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint_rounded, size: 64),
            const SizedBox(height: 16),
            const Text(
              'افتح حسابك بالبصمة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'تم تفعيل حماية الدخول بالبصمة لهذا الجهاز.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _loading ? null : _unlock,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint_rounded),
              label: const Text('استخدام البصمة'),
            ),
          ],
        ),
      ),
    ),
  );
}

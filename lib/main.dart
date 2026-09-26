import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/app_config/app_config_controller.dart';
import 'core/app_config/app_config_repository.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/portal/data/portal_repository.dart';
import 'features/portal/presentation/portal_controller.dart';
import 'features/portal/presentation/portal_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize Auth Dependencies
  final authRepository = AuthRepository(apiClient: apiClient, storage: storage);
  final authController = AuthController(repository: authRepository);

  // Initialize Portal Dependencies (dashboard/packages/invoices/account)
  final portalRepository = PortalRepository(apiClient: apiClient);

  runApp(
    MyApp(
      authController: authController,
      authRepository: authRepository,
      portalRepository: portalRepository,
      appConfigController: appConfigController,
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthController authController;
  final AuthRepository authRepository;
  final PortalRepository portalRepository;
  final AppConfigController appConfigController;

  const MyApp({
    super.key,
    required this.authController,
    required this.authRepository,
    required this.portalRepository,
    required this.appConfigController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.appConfigController.loadCached());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appConfigController,
      builder: (context, _) => MaterialApp(
        title: 'بوابة التكامل نت',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(token: widget.appConfigController.config.theme),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: _SessionGate(
          authController: widget.authController,
          authRepository: widget.authRepository,
          portalRepository: widget.portalRepository,
          appConfigController: widget.appConfigController,
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
  final PortalRepository portalRepository;
  final AppConfigController appConfigController;

  const _SessionGate({
    required this.authController,
    required this.authRepository,
    required this.portalRepository,
    required this.appConfigController,
  });

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<bool> _isAuthenticated = widget.authRepository
      .isAuthenticated();
  // App configuration can refresh after the portal has opened. Keep this
  // controller stable across that theme/configuration rebuild; otherwise the
  // visible shell receives a fresh controller that has never loaded data.
  late final PortalController _portalController = PortalController(
    repository: widget.portalRepository,
  );
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
          if (!_refreshedConfig) {
            _refreshedConfig = true;
            unawaited(widget.appConfigController.refresh());
          }
          return PortalShell(
            controller: _portalController,
            authController: widget.authController,
            appConfigController: widget.appConfigController,
          );
        }
        return LoginScreen(
          authController: widget.authController,
          portalRepository: widget.portalRepository,
          appConfigController: widget.appConfigController,
        );
      },
    );
  }
}

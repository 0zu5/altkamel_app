import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // Initialize Auth Dependencies
  final authRepository = AuthRepository(apiClient: apiClient, storage: storage);
  final authController = AuthController(repository: authRepository);

  // Initialize Portal Dependencies (dashboard/packages/invoices/account)
  final portalRepository = PortalRepository(apiClient: apiClient);

  runApp(MyApp(
    authController: authController,
    authRepository: authRepository,
    portalRepository: portalRepository,
  ));
}

class MyApp extends StatelessWidget {
  final AuthController authController;
  final AuthRepository authRepository;
  final PortalRepository portalRepository;

  const MyApp({
    super.key,
    required this.authController,
    required this.authRepository,
    required this.portalRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بوابة التكامل نت',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The app mirrors the Arabic, right-to-left altkamel-website portal,
      // so the whole app is forced to RTL regardless of device locale.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: _SessionGate(
        authController: authController,
        authRepository: authRepository,
        portalRepository: portalRepository,
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

  const _SessionGate({
    required this.authController,
    required this.authRepository,
    required this.portalRepository,
  });

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<bool> _isAuthenticated = widget.authRepository.isAuthenticated();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAuthenticated,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          return PortalShell(
            controller: PortalController(repository: widget.portalRepository),
            authController: widget.authController,
          );
        }
        return LoginScreen(
          authController: widget.authController,
          portalRepository: widget.portalRepository,
        );
      },
    );
  }
}

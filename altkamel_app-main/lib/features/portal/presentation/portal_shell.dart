import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import 'account_tab.dart';
import 'dashboard_tab.dart';
import 'invoices_tab.dart';
import 'packages_tab.dart';
import 'portal_controller.dart';

/// The logged-in shell: a bottom-nav with the four portal tabs, sharing
/// one [PortalController] so switching tabs doesn't re-fetch data that's
/// already loaded.
class PortalShell extends StatefulWidget {
  final PortalController controller;
  final AuthController authController;

  const PortalShell({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _tabIndex = 0;
  bool _leavingToLogin = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadAll();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _leavingToLogin) return;
    if (widget.controller.sessionExpired) {
      _goToLogin();
    }
  }

  Future<void> _logout() async {
    await widget.authController.logout();
    if (mounted) _goToLogin();
  }

  void _goToLogin() {
    if (_leavingToLogin) return;
    _leavingToLogin = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authController: widget.authController,
          portalRepository: widget.controller.repository,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(controller: widget.controller, onGoToPackages: () {
        setState(() => _tabIndex = 1);
      }),
      PackagesTab(controller: widget.controller),
      InvoicesTab(controller: widget.controller),
      AccountTab(controller: widget.controller, onLogout: _logout),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tabIndex, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        indicatorColor: AppColors.indigo.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard, color: AppColors.indigo),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering, color: AppColors.indigo),
            label: 'الباقات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.indigo),
            label: 'الفواتير',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.indigo),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

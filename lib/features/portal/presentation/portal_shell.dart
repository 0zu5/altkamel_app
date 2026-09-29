import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_config/app_config_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import 'account_tab.dart';
import 'dashboard_tab.dart';
import 'invoices_tab.dart';
import 'packages_tab.dart';
import 'portal_controller.dart';
import 'towers_tab.dart';

/// The logged-in shell: a bottom-nav with the four portal tabs, sharing
/// one [PortalController] so switching tabs doesn't re-fetch data that's
/// already loaded.
class PortalShell extends StatefulWidget {
  final PortalController controller;
  final AuthController authController;
  final AppConfigController appConfigController;

  const PortalShell({
    super.key,
    required this.controller,
    required this.authController,
    required this.appConfigController,
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

  void _selectTab(int index) {
    setState(() => _tabIndex = index);
    // A tab must never present an empty profile/invoice view simply because
    // the first dashboard request failed while Android was reconnecting.
    if (widget.controller.user == null && !widget.controller.isLoading) {
      unawaited(widget.controller.loadAll());
    } else if (index == 2 && !widget.controller.invoicesLoading) {
      unawaited(widget.controller.loadInvoices());
    }
  }

  void _showPackages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PackagesTab(controller: widget.controller),
      ),
    );
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
          appConfigController: widget.appConfigController,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        controller: widget.controller,
        onGoToPackages: () {
          _showPackages();
        },
        appConfigController: widget.appConfigController,
      ),
      TowersTab(controller: widget.controller),
      InvoicesTab(controller: widget.controller),
      AccountTab(controller: widget.controller, onLogout: _logout),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tabIndex, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _selectTab,
        indicatorColor: AppColors.indigo.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard, color: AppColors.indigo),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.cell_tower_outlined),
            selectedIcon: Icon(Icons.cell_tower, color: AppColors.indigo),
            label: 'الأبراج',
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

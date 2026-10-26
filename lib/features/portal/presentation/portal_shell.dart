import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_config/app_config_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/data/biometric_login_service.dart';
import '../../auth/data/account_session_store.dart';
import '../../auth/data/auth_repository.dart';
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
  final ThemeModeController themeModeController;
  final BiometricLoginService biometricLoginService;

  const PortalShell({
    super.key,
    required this.controller,
    required this.authController,
    required this.appConfigController,
    required this.themeModeController,
    required this.biometricLoginService,
  });

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  late int _tabIndex;
  bool _leavingToLogin = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.controller.selectedTabIndex;
    widget.controller.addListener(_onControllerChanged);
    // Retain already-painted portal data when MaterialApp is rebuilt for a
    // local day/night preference change. A new account controller starts
    // empty and therefore still performs its initial load immediately.
    if (!widget.controller.hasLoadedCoreData && !widget.controller.isLoading) {
      unawaited(widget.controller.loadAll());
    }
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
    widget.controller.selectedTabIndex = index;
    setState(() => _tabIndex = index);
    // A tab must never present an empty profile/invoice view simply because
    // the first dashboard request failed while Android was reconnecting.
    if (widget.controller.user == null && !widget.controller.isLoading) {
      unawaited(widget.controller.loadAll(force: true));
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

  Future<void> _manageAccounts() async {
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSwitcher(
        repository: widget.authController.repository,
      ),
    );
    if (!mounted || action == null) return;

    if (action.addAnother) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            authController: widget.authController,
            portalRepository: widget.controller.repository,
            appConfigController: widget.appConfigController,
            themeModeController: widget.themeModeController,
            biometricLoginService: widget.biometricLoginService,
          ),
        ),
        (route) => false,
      );
      return;
    }

    final accountId = action.accountId;
    if (accountId == null || !await widget.authController.repository.switchAccount(accountId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الحساب المحفوظ. سجّل الدخول به مرة أخرى.')),
        );
      }
      return;
    }
    widget.controller.resetForAccountSwitch();
    setState(() => _tabIndex = 0);
    await widget.controller.loadAll(force: true);
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
          themeModeController: widget.themeModeController,
          biometricLoginService: widget.biometricLoginService,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      AccountTab(
        controller: widget.controller,
        onLogout: _logout,
        themeModeController: widget.themeModeController,
        biometricLoginService: widget.biometricLoginService,
        onManageAccounts: _manageAccounts,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tabIndex, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _selectTab,
        indicatorColor: colors.primaryContainer,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard, color: colors.primary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.cell_tower_outlined),
            selectedIcon: Icon(Icons.cell_tower, color: colors.primary),
            label: 'الأبراج',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: colors.primary),
            label: 'الفواتير',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: colors.primary),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _AccountAction {
  final String? accountId;
  final bool addAnother;

  const _AccountAction.switchTo(this.accountId) : addAnother = false;
  const _AccountAction.add() : accountId = null, addAnother = true;
}

class _AccountSwitcher extends StatefulWidget {
  final AuthRepository repository;

  const _AccountSwitcher({required this.repository});

  @override
  State<_AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends State<_AccountSwitcher> {
  late final Future<List<SavedAccount>> _accounts = widget.repository.savedAccounts();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: FutureBuilder<List<SavedAccount>>(
        future: _accounts,
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? const <SavedAccount>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الحسابات المسجلة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'تُحفظ جلسات الدخول المشفّرة على هذا الجهاز فقط. لا نحفظ كلمات المرور.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد حسابات إضافية محفوظة بعد.', textAlign: TextAlign.center),
                )
              else
                ...accounts.map(
                  (account) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(account.username),
                    subtitle: const Text('اضغط للتبديل إلى هذا الحساب'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.of(context).pop(_AccountAction.switchTo(account.id)),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(const _AccountAction.add()),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('إضافة حساب آخر'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

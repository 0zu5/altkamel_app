import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';
import 'widgets/redeem_dialog.dart';

/// Profile info + account actions: redeem a code, toggle auto-renew,
/// change password, and log out.
class AccountTab extends StatelessWidget {
  final PortalController controller;
  final VoidCallback onLogout;

  const AccountTab({
    super.key,
    required this.controller,
    required this.onLogout,
  });

  Future<void> _openRedeemDialog(BuildContext context) async {
    final message = await showRedeemDialog(context, controller);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    final message = await showDialog<String?>(
      context: context,
      builder: (context) => _ChangePasswordDialog(controller: controller),
    );
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final user = controller.user;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'حسابي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 20),
            PortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.indigo.withValues(
                          alpha: 0.1,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.indigo,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              user?.phone ?? user?.username ?? '',
                              style: const TextStyle(
                                color: AppColors.slate500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'البريد الإلكتروني',
                    value: user?.email,
                  ),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'الهاتف',
                    value: user?.phone,
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'تاريخ التسجيل',
                    value: user?.registeredOn != null
                        ? Formatters.arabicDate(user!.registeredOn)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PortalCard(
              child: Row(
                children: [
                  const Icon(Icons.autorenew_rounded, color: AppColors.indigo),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'التجديد التلقائي',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: user?.autoRenew ?? false,
                    activeThumbColor: AppColors.indigo,
                    onChanged: (value) async {
                      final message = await controller.toggleAutoRenew(value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PortalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.card_giftcard_outlined,
                    label: 'شحن رصيد',
                    onTap: () => _openRedeemDialog(context),
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.lock_outline,
                    label: 'تغيير كلمة المرور',
                    onTap: () => _openChangePasswordDialog(context),
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    color: AppColors.rose700,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.slate400),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const Spacer(),
          Text(
            (value == null || value!.isEmpty) ? 'غير محدد' : value!,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.indigo),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: color ?? AppColors.slate900,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        color: AppColors.slate400,
      ),
      onTap: onTap,
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final PortalController controller;

  const _ChangePasswordDialog({required this.controller});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentController.text.isEmpty || _newController.text.isEmpty) {
      setState(() => _error = 'يرجى تعبئة كلا الحقلين.');
      return;
    }
    if (_newController.text.length < 6) {
      setState(
        () => _error = 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل.',
      );
      return;
    }
    setState(() => _error = null);
    final message = await widget.controller.changePassword(
      newPassword: _newController.text,
      currentPassword: _currentController.text,
    );
    if (mounted) Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => FilledButton(
            onPressed: widget.controller.actionLoading ? null : _submit,
            child: widget.controller.actionLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تغيير'),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/app_config/app_config_controller.dart';
import '../../portal/data/portal_repository.dart';
import '../../portal/presentation/portal_controller.dart';
import '../../portal/presentation/portal_shell.dart';
import 'auth_controller.dart';
import 'widgets/error_banner.dart';
import 'widgets/gradient_button.dart';
import 'widgets/login_hero_header.dart';

/// Login screen mirroring the design of the altkamel-website
/// `/portal/login` page: a gradient "brand" header (logo + headline),
/// an Arabic, RTL form card with username/password, a "remember me"
/// toggle and a gradient submit button.
class LoginScreen extends StatefulWidget {
  final AuthController authController;
  final PortalRepository portalRepository;
  final AppConfigController appConfigController;

  const LoginScreen({
    super.key,
    required this.authController,
    required this.portalRepository,
    required this.appConfigController,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _whatsappSupportUrl = 'https://wa.me/218923339798';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // Dismiss keyboard

    final success = await widget.authController.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Configuration is an optional experience enhancement. It must never
      // delay a successful login or trap the customer on the loading state.
      unawaited(widget.appConfigController.refresh());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PortalShell(
            controller: PortalController(repository: widget.portalRepository),
            authController: widget.authController,
            appConfigController: widget.appConfigController,
          ),
        ),
      );
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse(_whatsappSupportUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    // The hero header is a dark gradient, so the status bar icons need to
    // be light to stay visible against it.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoginHeroHeader(topInset: topInset),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PortalBadge(),
                      const SizedBox(height: 20),
                      Text(
                        'أهلاً بعودتك',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أدخل بيانات حسابك للوصول إلى لوحة التحكم',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                      const SizedBox(height: 28),
                      _SupportFooter(onTapSupport: _openSupport),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: ListenableBuilder(
          listenable: widget.authController,
          builder: (context, _) {
            final controller = widget.authController;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  alignment: Alignment.topCenter,
                  child: controller.errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ErrorBanner(message: controller.errorMessage!),
                        )
                      : const SizedBox.shrink(),
                ),
                const _FieldLabel('اسم المستخدم'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    hintText: 'مثال: ATK-mohammedmustafa',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'الرجاء إدخال اسم المستخدم'
                      : null,
                ),
                const SizedBox(height: 20),
                const _FieldLabel('كلمة المرور'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'الرجاء إدخال كلمة المرور'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: _rememberMe,
                      activeThumbColor: AppColors.indigo,
                      onChanged: (value) => setState(() => _rememberMe = value),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'تذكر بيانات الدخول',
                      style: TextStyle(
                        color: AppColors.slate700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'الدخول إلى حسابي',
                  loadingLabel: 'جاري التحقق من البيانات...',
                  isLoading: controller.isLoading,
                  onPressed: _handleLogin,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: AppColors.slate700,
        fontSize: 13,
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  const _PortalBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.indigo,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'بوابة مشتركي التكامل نت',
              style: TextStyle(
                color: AppColors.indigo,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportFooter extends StatelessWidget {
  final VoidCallback onTapSupport;

  const _SupportFooter({required this.onTapSupport});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'تحتاج مساعدة؟ ',
          style: TextStyle(
            color: AppColors.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: onTapSupport,
          child: const Text(
            'تواصل مع الدعم الفني',
            style: TextStyle(
              color: AppColors.indigo,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

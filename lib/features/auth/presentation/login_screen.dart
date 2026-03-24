import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/ui/app_feedback.dart';
import '../../pos/presentation/widgets/pos_select.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _showServerConfig = false;
  String lang = 'ar';

  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final baseUrlCtrl = TextEditingController();
  final clientIdCtrl = TextEditingController();
  final clientSecretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitialState);
  }

  Future<void> _loadInitialState() async {
    final repo = ref.read(authRepositoryProvider);
    final saved = await repo.readSavedLogin();
    final connectionConfig = await repo.readConnectionConfig();
    if (!mounted) return;
    if (userCtrl.text.trim().isEmpty &&
        (saved.username?.trim().isNotEmpty ?? false)) {
      userCtrl.text = saved.username!.trim();
    }
    if (passCtrl.text.isEmpty && (saved.password?.isNotEmpty ?? false)) {
      passCtrl.text = saved.password!;
    }
    if (baseUrlCtrl.text.trim().isEmpty) {
      baseUrlCtrl.text = connectionConfig.baseUrl;
    }
    if (clientIdCtrl.text.trim().isEmpty &&
        connectionConfig.clientId.trim().isNotEmpty) {
      clientIdCtrl.text = connectionConfig.clientId.trim();
    }
    if (clientSecretCtrl.text.isEmpty &&
        connectionConfig.clientSecret.trim().isNotEmpty) {
      clientSecretCtrl.text = connectionConfig.clientSecret.trim();
    }
    if (connectionConfig.clientId.trim().isEmpty ||
        connectionConfig.clientSecret.trim().isEmpty) {
      setState(() => _showServerConfig = true);
    }
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    baseUrlCtrl.dispose();
    clientIdCtrl.dispose();
    clientSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = userCtrl.text.trim();
    final password = passCtrl.text;
    final repo = ref.read(authRepositoryProvider);

    if (username.isEmpty || password.isEmpty) {
      AppFeedback.warning(context, 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }

    final storedConfig = await repo.readConnectionConfig();
    final baseUrl = baseUrlCtrl.text.trim().isNotEmpty
        ? baseUrlCtrl.text.trim()
        : storedConfig.baseUrl;
    final clientId = clientIdCtrl.text.trim().isNotEmpty
        ? clientIdCtrl.text.trim()
        : storedConfig.clientId.trim();
    final clientSecret = clientSecretCtrl.text.trim().isNotEmpty
        ? clientSecretCtrl.text.trim()
        : storedConfig.clientSecret.trim();

    if (baseUrl.isEmpty || clientId.isEmpty || clientSecret.isEmpty) {
      if (!mounted) return;
      setState(() => _showServerConfig = true);
      AppFeedback.warning(
        context,
        'أدخل رابط السيرفر و Passport Client ID و Client Secret قبل تسجيل الدخول',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await repo.saveConnectionConfig(
        baseUrl: baseUrl,
        clientId: clientId,
        clientSecret: clientSecret,
      );
      final result = await repo.signIn(username: username, password: password);

      if (!mounted) return;
      final successMessage = result.usedOfflineCache
          ? 'تم فتح الجلسة المحلية بدون إنترنت'
          : result.syncStartedInBackground
          ? 'تم تسجيل الدخول وتبدأ مزامنة المنتجات في الخلفية'
          : 'تم تسجيل الدخول بنجاح';
      AppFeedback.success(context, successMessage);
      Navigator.pushReplacementNamed(context, AppRoutes.pos);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, _formatError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      return text.substring('Exception:'.length).trim();
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;

          final leftPanel = _LeftPanel(
            lang: lang,
            onLangChanged: (v) => setState(() => lang = v),
            userCtrl: userCtrl,
            passCtrl: passCtrl,
            baseUrlCtrl: baseUrlCtrl,
            clientIdCtrl: clientIdCtrl,
            clientSecretCtrl: clientSecretCtrl,
            showServerConfig: _showServerConfig,
            onToggleServerConfig: () {
              setState(() => _showServerConfig = !_showServerConfig);
            },
            loading: _loading,
            onLogin: _login,
          );

          const rightPanel = _RightLogo();

          if (isNarrow) {
            return Scaffold(
              backgroundColor: const Color(0xFF0B86B4),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      _LanguageBar(
                        value: lang,
                        onChanged: (v) => setState(() => lang = v),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _RightLogo(isNarrow: true),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: leftPanel,
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFF0B86B4),
                    child: SafeArea(
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _LanguageBar(
                                value: lang,
                                onChanged: (v) => setState(() => lang = v),
                              ),
                            ),
                          ),
                          Center(child: leftPanel),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Container(color: Colors.white, child: rightPanel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.lang,
    required this.onLangChanged,
    required this.userCtrl,
    required this.passCtrl,
    required this.baseUrlCtrl,
    required this.clientIdCtrl,
    required this.clientSecretCtrl,
    required this.showServerConfig,
    required this.onToggleServerConfig,
    required this.loading,
    required this.onLogin,
  });

  final String lang;
  final ValueChanged<String> onLangChanged;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final TextEditingController baseUrlCtrl;
  final TextEditingController clientIdCtrl;
  final TextEditingController clientSecretCtrl;
  final bool showServerConfig;
  final VoidCallback onToggleServerConfig;
  final bool loading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: Offset(0, 10),
                  color: Color(0x26000000),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D2F3A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'تسجيل دخول الشركة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    children: [
                      _InputField(
                        controller: userCtrl,
                        label: 'اسم المستخدم',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 12),
                      _InputField(
                        controller: passCtrl,
                        label: 'كلمة المرور',
                        icon: Icons.lock,
                        obscure: true,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onToggleServerConfig,
                          icon: Icon(
                            showServerConfig
                                ? Icons.settings_rounded
                                : Icons.settings_outlined,
                            size: 18,
                          ),
                          label: Text(
                            showServerConfig
                                ? 'إخفاء إعدادات الاتصال'
                                : 'إظهار إعدادات الاتصال',
                          ),
                        ),
                      ),
                      if (showServerConfig) ...[
                        _InputField(
                          controller: baseUrlCtrl,
                          label: 'رابط السيرفر',
                          icon: Icons.link_rounded,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          controller: clientIdCtrl,
                          label: 'Passport Client ID',
                          icon: Icons.vpn_key_outlined,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          controller: clientSecretCtrl,
                          label: 'Passport Client Secret',
                          icon: Icons.key_rounded,
                          obscure: true,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'بعد نجاح الدخول يتم فتح النظام مباشرة، وتبدأ مزامنة المنتجات في الخلفية. وإذا كانت البيانات محفوظة سابقاً يمكنك الدخول بدون إنترنت.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5F7FA0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: loading ? null : onLogin,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1F2A37)),
        filled: true,
        fillColor: const Color(0xFFEAF3FF),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF0B86B4), width: 1.5),
        ),
      ),
    );
  }
}

class _RightLogo extends StatelessWidget {
  const _RightLogo({this.isNarrow = false});

  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo.jpg',
        fit: BoxFit.contain,
        width: isNarrow ? 320 : 520,
      ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  const _LanguageBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 34,
      child: PosSelect<String>(
        options: const [
          PosSelectOption(value: 'ar', label: 'العربية - Arabic'),
          PosSelectOption(value: 'en', label: 'English - الإنجليزية'),
        ],
        value: value,
        hintText: 'اختر اللغة',
        height: 34,
        borderRadius: 6,
        fieldPadding: const EdgeInsets.symmetric(horizontal: 10),
        enableSearch: false,
        dropdownItemExtent: 32,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

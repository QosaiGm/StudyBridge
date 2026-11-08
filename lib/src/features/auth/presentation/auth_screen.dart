import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _reset = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    if (!auth.isConfigured) {
      setState(() {
        _error = true;
        _message =
            'إعدادات Supabase غير مكتملة. راجع ملف README لتفعيل الحساب.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_reset) {
        await auth.resetPassword(_email.text);
        _show('أرسلنا رابط استعادة كلمة المرور إلى بريدك.');
      } else if (_signUp) {
        await auth.signUp(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
        );
        _show('تم إنشاء الحساب. تحقق من بريدك لتأكيده.');
        setState(() => _signUp = false);
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      final text = e.message.toLowerCase();
      _show(
        text.contains('invalid login credentials')
            ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
            : text.contains('already registered')
            ? 'هذا البريد مسجل من قبل. جرّب تسجيل الدخول.'
            : 'تعذر تسجيل الدخول. تحقق من البيانات وحاول مجدداً.',
        error: true,
      );
    } catch (_) {
      _show('تعذر إكمال الطلب الآن. حاول مرة أخرى.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text, {bool error = false}) {
    if (mounted) {
      setState(() {
        _message = text;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _reset
        ? 'استعادة كلمة المرور'
        : _signUp
        ? 'أنشئ حسابك'
        : 'مرحباً بعودتك';
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              StudyBridgeColors.elevated,
              StudyBridgeColors.background,
              StudyBridgeColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reset
                                  ? 'سنرسل إليك رابطاً آمناً لإعادة تعيينها.'
                                  : _signUp
                                  ? 'ابدأ مساحة هادئة للدراسة والنمو.'
                                  : 'مساحتك الهادئة للدراسة بانتظارك.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            if (!SupabaseConfig.isConfigured) ...[
                              const _SetupNotice(),
                              const SizedBox(height: 16),
                            ],
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  if (_signUp && !_reset) ...[
                                    _input(
                                      _name,
                                      'الاسم الذي تحب أن نناديك به',
                                      Icons.person_outline_rounded,
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'اكتب اسمك من فضلك'
                                          : null,
                                    ),
                                    const SizedBox(height: 13),
                                  ],
                                  _input(
                                    _email,
                                    'البريد الإلكتروني',
                                    Icons.mail_outline_rounded,
                                    type: TextInputType.emailAddress,
                                    validator: (v) =>
                                        v == null ||
                                            !v.contains('@') ||
                                            !v.contains('.')
                                        ? 'تحقق من صيغة البريد الإلكتروني'
                                        : null,
                                  ),
                                  if (!_reset) ...[
                                    const SizedBox(height: 13),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: _hidePassword,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      decoration: InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _hidePassword
                                              ? 'إظهار كلمة المرور'
                                              : 'إخفاء كلمة المرور',
                                          onPressed: () => setState(
                                            () =>
                                                _hidePassword = !_hidePassword,
                                          ),
                                          icon: Icon(
                                            _hidePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (v) => v == null || v.isEmpty
                                          ? 'اكتب كلمة المرور'
                                          : _signUp && v.length < 8
                                          ? 'استخدم ٨ أحرف على الأقل'
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 13),
                              _InlineMessage(message: _message!, error: _error),
                            ],
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _reset
                                          ? 'إرسال رابط الاستعادة'
                                          : _signUp
                                          ? 'إنشاء حساب'
                                          : 'تسجيل الدخول',
                                    ),
                            ),
                            if (!_reset && !_signUp)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => setState(() {
                                    _reset = true;
                                    _message = null;
                                  }),
                                  child: const Text('نسيت كلمة المرور؟'),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _reset
                                      ? 'تذكرت كلمة المرور؟'
                                      : _signUp
                                      ? 'لديك حساب بالفعل؟'
                                      : 'ليس لديك حساب؟',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _reset = false;
                                    _signUp = !_signUp;
                                    _message = null;
                                  }),
                                  child: Text(
                                    _reset
                                        ? 'العودة للدخول'
                                        : _signUp
                                        ? 'تسجيل الدخول'
                                        : 'إنشاء حساب',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'مساحة خاصة، لك ولمن تختار أن تدرس معه.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? type,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: type,
    textDirection: type == TextInputType.emailAddress
        ? TextDirection.ltr
        : TextDirection.rtl,
    textAlign: TextAlign.right,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: validator,
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [StudyBridgeColors.lavender, StudyBridgeColors.purple],
          ),
          boxShadow: [
            BoxShadow(
              color: StudyBridgeColors.purple.withValues(alpha: .22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: Colors.white,
          size: 31,
        ),
      ),
      const SizedBox(height: 10),
      Text('StudyBridge', style: Theme.of(context).textTheme.headlineLarge),
      Text(
        'ندرس معاً، وننمو معاً',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: StudyBridgeColors.lilacWash,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: StudyBridgeColors.purple),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'واجهة الحساب جاهزة. لإرسال الطلبات فعلياً، أضف رابط مشروع Supabase ومفتاحه العام عند التشغيل.',
            style: TextStyle(color: StudyBridgeColors.ink, height: 1.55),
          ),
        ),
      ],
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.error});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFF3B2029) : const Color(0xFF1D3027),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, style: const TextStyle(color: StudyBridgeColors.ink)),
  );
}

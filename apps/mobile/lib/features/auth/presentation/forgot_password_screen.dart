import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../../shared/widgets/calm_text_field.dart';
import '../../../shared/widgets/soft_header.dart';
import 'auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) {
      return trEn(context, 'E-posta gerekli', 'Email is required');
    }
    if (!s.contains('@')) {
      return trEn(context, 'Geçerli bir e-posta gir', 'Enter a valid email');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    ref.read(authControllerProvider.notifier).clearError();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_email.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trEn(
            context,
            'E-postanı kontrol et. Kod geldiyse yeni şifre belirlemek için devam et.',
            'Check your email. If you received a code, continue to set a new password.',
          ),
        ),
      ),
    );
    await context.push(RoutePaths.resetPassword);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftHeader(
                title: trEn(context, 'Şifremi unuttum', 'Forgot password'),
                subtitle: trEn(
                  context,
                  'Kayıtlı e-postana sıfırlama kodu göndeririz',
                  'We will send a reset code to your registered email',
                ),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _email,
                label: trEn(context, 'E-posta', 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                validator: _emailValidator,
              ),
              const SizedBox(height: 24),
              CalmCTAButton(
                label: trEn(context, 'Kod gönder', 'Send code'),
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

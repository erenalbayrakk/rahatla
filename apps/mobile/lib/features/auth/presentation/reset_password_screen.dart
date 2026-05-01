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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken?.trim() ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  String? _tokenValidator(String? v) {
    if ((v?.trim().length ?? 0) < 32) {
      return trEn(context, 'E-postadaki kodu eksiksiz gir', 'Enter the full code from the email');
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    if ((v ?? '').length < 8) {
      return trEn(context, 'En az 8 karakter', 'At least 8 characters');
    }
    return null;
  }

  String? _password2Validator(String? v) {
    if (v != _password.text) {
      return trEn(context, 'Şifreler eşleşmiyor', 'Passwords do not match');
    }
    return _passwordValidator(v);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    ref.read(authControllerProvider.notifier).clearError();
    final ok = await ref.read(authControllerProvider.notifier).resetPassword(
          token: _token.text.trim(),
          password: _password.text,
        );
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
            'Şifren güncellendi. Giriş yapabilirsin.',
            'Password updated. You can sign in.',
          ),
        ),
      ),
    );
    if (!mounted) return;
    context.go(RoutePaths.login);
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
                title: trEn(context, 'Yeni şifre', 'New password'),
                subtitle: trEn(
                  context,
                  'E-postadaki kodu ve yeni şifreni gir',
                  'Enter the code from email and your new password',
                ),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _token,
                label: trEn(context, 'Sıfırlama kodu', 'Reset code'),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _tokenValidator,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _password,
                label: trEn(context, 'Yeni şifre', 'New password'),
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: _passwordValidator,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _password2,
                label: trEn(context, 'Yeni şifre tekrar', 'New password again'),
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: _password2Validator,
              ),
              const SizedBox(height: 24),
              CalmCTAButton(
                label: trEn(context, 'Şifreyi kaydet', 'Save password'),
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

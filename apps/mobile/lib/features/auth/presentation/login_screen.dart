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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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

  String? _passwordValidator(String? v) {
    if ((v ?? '').length < 8) {
      return trEn(context, 'En az 8 karakter', 'At least 8 characters');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    ref.read(authControllerProvider.notifier).clearError();
    await ref.read(authControllerProvider.notifier).login(
          _email.text.trim(),
          _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    final err = ref.read(authControllerProvider).errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
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
                title: trEn(context, 'Tekrar hoş geldin', 'Welcome back'),
                subtitle: trEn(context, 'Hesabına giriş yap', 'Sign in to your account'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 8),
              CalmTextField(
                controller: _email,
                label: trEn(context, 'E-posta', 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _password,
                label: trEn(context, 'Şifre', 'Password'),
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: _passwordValidator,
                onChanged: (_) {},
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.push(RoutePaths.forgotPassword),
                  child: Text(
                    trEn(context, 'Şifremi unuttum', 'Forgot password'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CalmCTAButton(
                label: trEn(context, 'Giriş yap', 'Sign in'),
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    context.pushReplacement(RoutePaths.register),
                child: Text(trEn(context, 'Hesap oluştur', 'Create account')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

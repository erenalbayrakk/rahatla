import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../../shared/widgets/calm_text_field.dart';
import '../../../shared/widgets/soft_header.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _token;
  final _formKey = GlobalKey<FormState>();
  var _loading = false;
  var _autoTried = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken?.trim() ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoVerify());
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _tryAutoVerify() async {
    if (_autoTried) return;
    final t = _token.text.trim();
    if (t.length < 32) return;
    _autoTried = true;
    await _verify(t);
  }

  String? _tokenValidator(String? v) {
    if ((v?.trim().length ?? 0) < 32) {
      return trEn(context, 'Doğrulama kodunu eksiksiz gir', 'Enter the full verification code');
    }
    return null;
  }

  Future<void> _verify(String raw) async {
    setState(() => _loading = true);
    ref.read(authControllerProvider.notifier).clearError();
    final ok =
        await ref.read(authControllerProvider.notifier).verifyEmail(raw.trim());
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
        content: Text(trEn(context, 'E-posta doğrulandı.', 'Your email is verified.')),
      ),
    );
    final auth = ref.read(authControllerProvider);
    if (!mounted) return;
    if (auth.status == AuthStatus.authenticated) {
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      context.go(RoutePaths.home);
    } else {
      context.go(RoutePaths.login);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _verify(_token.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftHeader(
                title: trEn(context, 'E-posta doğrula', 'Verify email'),
                subtitle: trEn(
                  context,
                  'Bağlantıya tıkladıysan işlem tamamlanmış olabilir; yoksa kodu buraya yapıştır',
                  'If you used the link, you may be done. Otherwise paste the code here',
                ),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 8),
              Text(
                trEn(
                  context,
                  'Kodu e-postanın içinde veya doğrulama bağlantısının adres çubuğunda bulabilirsin.',
                  'You can find the code in the email or in the verification link URL.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _token,
                label: trEn(context, 'Doğrulama kodu', 'Verification code'),
                textInputAction: TextInputAction.done,
                autocorrect: false,
                validator: _tokenValidator,
              ),
              const SizedBox(height: 24),
              CalmCTAButton(
                label: trEn(context, 'Doğrula', 'Verify'),
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

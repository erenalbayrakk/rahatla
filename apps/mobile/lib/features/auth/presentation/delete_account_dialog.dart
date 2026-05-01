import 'package:flutter/material.dart';

import '../../../core/locale/locale_text.dart';

/// Onaylanırsa girilen şifreyi döner; iptal veya kapatmada `null`.
Future<String?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(trEn(context, 'Hesabı sil', 'Delete account')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trEn(
                context,
                'Profilin, geçmiş oturum bağlantıların ve bu e-posta ile girişin kapanır. '
                'Aynı e-posta ile yeni hesap açabilirsin. Bu işlem geri alınamaz.',
                'Your profile, session history, and sign-in with this email will be closed. '
                'You may create a new account with the same email. This action cannot be undone.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: trEn(context, 'Şifren', 'Your password'),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return trEn(context, 'Şifre gerekli', 'Password is required');
                }
                if (v.length < 8) {
                  return trEn(context, 'En az 8 karakter', 'At least 8 characters');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(trEn(context, 'Vazgeç', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(_password.text);
          },
          child: Text(trEn(context, 'Hesabı sil', 'Delete account')),
        ),
      ],
    );
  }
}

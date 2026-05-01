import 'package:flutter/material.dart';

import '../../../core/locale/locale_text.dart';

Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trEn(ctx, 'Çıkış', 'Log out')),
      content: Text(
        trEn(ctx, 'Çıkış yapmak istediğine emin misin?', 'Are you sure you want to log out?'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(trEn(ctx, 'Vazgeç', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(trEn(ctx, 'Çıkış', 'Log out')),
        ),
      ],
    ),
  );
  return result ?? false;
}

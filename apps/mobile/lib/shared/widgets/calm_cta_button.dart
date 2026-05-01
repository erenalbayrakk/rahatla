import 'package:flutter/material.dart';

/// Birincil / ikincil eylem — tema ile hizalı, min 52 yükseklik, erişilebilir dokunma alanı.
class CalmCTAButton extends StatelessWidget {
  const CalmCTAButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final effectiveOnPressed =
        (isLoading || onPressed == null) ? null : onPressed;

    final child =
        isLoading
            ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? scheme.primary : scheme.onPrimary,
              ),
            )
            : Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );

    if (outlined) {
      final base = theme.outlinedButtonTheme.style;
      return Semantics(
        button: true,
        label: label,
        enabled: effectiveOnPressed != null,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: effectiveOnPressed,
            style: base,
            child: child,
          ),
        ),
      );
    }

    final base = theme.filledButtonTheme.style;
    return Semantics(
      button: true,
      label: label,
      enabled: effectiveOnPressed != null,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: effectiveOnPressed,
          style: base,
          child: child,
        ),
      ),
    );
  }
}

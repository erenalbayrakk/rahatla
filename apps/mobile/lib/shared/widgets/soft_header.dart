import 'package:flutter/material.dart';

/// İç sayfa üst başlığı — hiyerarşi: başlık (display küçük) + isteğe bağlı bağlam satırı.
class SoftHeader extends StatelessWidget {
  const SoftHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final centered = onBack == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                foregroundColor: scheme.onSurface,
              ),
            )
          else
            const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  centered
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onBack != null)
            const SizedBox(width: 48)
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

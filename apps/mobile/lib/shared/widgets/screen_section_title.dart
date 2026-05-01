import 'package:flutter/material.dart';

/// Bölüm başlığı: sayfa başlığından bir kademe küçük; destekleyici metin için `caption`.
class ScreenSectionTitle extends StatelessWidget {
  const ScreenSectionTitle(
    this.text, {
    super.key,
    this.caption,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  final String text;
  final String? caption;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.12,
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

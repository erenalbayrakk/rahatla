import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.28,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.spa_rounded,
                  size: 44,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              trEn(context, 'Burada dinlenirsin', 'Find calm here'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              trEn(
                context,
                'Terapi değil, randevu uygulaması da değil. '
                'Güvenli ve sıcak bir sohbet alanı.',
                'Not therapy. Not a booking app. '
                'A safe, warm place to talk.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    _Bullet(
                      icon: Icons.shield_outlined,
                      text: trEn(
                        context,
                        'Kurallı ve raporlanabilir ortam',
                        'Clear rules; easy reporting',
                      ),
                    ),
                    const Divider(height: 1),
                    _Bullet(
                      icon: Icons.volunteer_activism_outlined,
                      text: trEn(context, 'Onaylı dinleyenler', 'Verified listeners'),
                    ),
                    const Divider(height: 1),
                    _Bullet(
                      icon: Icons.lock_outline_rounded,
                      text: trEn(context, 'Gizliliğine saygı', 'Respect for your privacy'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            CalmCTAButton(
              label: trEn(context, 'Başla', 'Get started'),
              onPressed: () => context.push(RoutePaths.register),
            ),
            const SizedBox(height: 12),
            CalmCTAButton(
              label: trEn(context, 'Zaten hesabım var', 'I already have an account'),
              outlined: true,
              onPressed: () => context.push(RoutePaths.login),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

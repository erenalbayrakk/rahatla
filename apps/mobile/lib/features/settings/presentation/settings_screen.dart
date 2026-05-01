import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/locale/locale_text.dart';
import '../../../core/legal/legal_urls.dart';
import '../../../core/legal/trust_screens.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/screen_section_title.dart';
import '../../../shared/widgets/soft_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/delete_account_dialog.dart';
import '../../auth/presentation/logout_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> _openLegalUrl(
    BuildContext context,
    String raw,
    String emptyMessage,
  ) async {
    final url = raw.trim();
    if (url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emptyMessage)),
        );
      }
      return;
    }
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trEn(context, 'Geçersiz adres.', 'Invalid address.'),
            ),
          ),
        );
      }
      return;
    }
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Bağlantı açılamadı.', 'Could not open the link.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider);
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftHeader(
            title: trEn(context, 'Ayarlar', 'Settings'),
            subtitle: trEn(
              context,
              'Güvenlik, yasal metinler ve tercihler',
              'Security, legal pages and preferences',
            ),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ScreenSectionTitle(
                  trEn(context, 'Dil', 'Language'),
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language_rounded),
                        title: Text(
                          trEn(context, 'Uygulama dili', 'App language'),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Görüntüleme dilini seç',
                            'Choose the display language',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'tr',
                              label: Text('Türkçe'),
                            ),
                            ButtonSegment<String>(
                              value: 'en',
                              label: Text('English'),
                            ),
                          ],
                          selected: {locale.languageCode},
                          onSelectionChanged: (s) {
                            final next = s.firstOrNull ?? 'tr';
                            ref
                                .read(appLocaleProvider.notifier)
                                .setLanguageCode(next);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(
                    context,
                    'Güvenlik ve topluluk',
                    'Safety and community',
                  ),
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.health_and_safety_outlined),
                        title: Text(
                          trEn(context, 'Sağlık ve destek', 'Health and support'),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Profesyonel hizmet değildir; acil durum yönlendirmesi',
                            'Not a professional service; emergency guidance',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const HealthDisclaimerScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(
                          trEn(
                            context,
                            'Topluluk kuralları',
                            'Community guidelines',
                          ),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'UGC ve güvenli iletişim',
                            'UGC and safe communication',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const CommunityGuidelinesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(context, 'Yasal', 'Legal'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: Text(trEn(context, 'Gizlilik', 'Privacy')),
                        subtitle: Text(
                          LegalUrls.hasPrivacyUrl
                              ? trEn(
                                  context,
                                  'Politikayı tarayıcıda aç',
                                  'Open policy in browser',
                                )
                              : trEn(
                                  context,
                                  'Özet ekranı (tam metin için URL ekleyin)',
                                  'Summary screen (add URL for full text)',
                                ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          if (LegalUrls.hasPrivacyUrl) {
                            unawaited(
                              _openLegalUrl(
                                context,
                                LegalUrls.privacyPolicy,
                                '',
                              ),
                            );
                          } else {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyOverviewScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          trEn(context, 'Kullanım şartları', 'Terms of use'),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Harici bağlantı (yapılandırılırsa)',
                            'External link (if configured)',
                          ),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () {
                          if (LegalUrls.hasTermsUrl) {
                            unawaited(
                              _openLegalUrl(
                                context,
                                LegalUrls.termsOfService,
                                '',
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  trEn(
                                    context,
                                    'Kullanım şartları için LEGAL_TERMS_URL tanımlayın veya web sitenizde yayınlayıp mağaza kaydına ekleyin.',
                                    'Set LEGAL_TERMS_URL for terms of use, or publish on your site and add the link in the store listing.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(context, 'Tercihler', 'Preferences'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          trEn(context, 'Bildirimler', 'Notifications'),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Mesaj ve oturum bildirimleri',
                            'Message and session notifications',
                          ),
                        ),
                        value: true,
                        onChanged: (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                trEn(
                                  context,
                                  'MVP: tercihler yakında.',
                                  'MVP: preferences coming soon.',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.volume_up_outlined),
                        title: Text(trEn(context, 'Ses', 'Sound')),
                        subtitle: Text(
                          trEn(
                            context,
                            'Sesli görüşme ve tonlar',
                            'Call audio and ringtones',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(context, 'Mağaza ve ödemeler', 'Store and payments'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      Icons.storefront_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      trEn(
                        context,
                        'App Store — uygulama içi ödeme',
                        'App Store — in-app purchases',
                      ),
                    ),
                    subtitle: Text(
                      trEn(
                        context,
                        'Bakiye ve hediye satın alımları yayın öncesi StoreKit (IAP) ile sunulacaktır. Şu an harici ödeme App Store kurallarıyla çelişebilir.',
                        'Balance and gift purchases will be offered via StoreKit (IAP) before release. External payments may conflict with App Store rules for now.',
                      ),
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(context, 'Destek', 'Support'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: Text(
                      trEn(context, 'Yardım merkezi', 'Help center'),
                    ),
                    subtitle: Text(
                      trEn(
                        context,
                        'Topluluk kuralları ve güvenlik',
                        'Community rules and safety',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const CommunityGuidelinesScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                ScreenSectionTitle(
                  trEn(context, 'Hesap', 'Account'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person_off_outlined,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          trEn(context, 'Hesabımı sil', 'Delete my account'),
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Kalıcı olarak kapat (App Store gereksinimi)',
                            'Permanently close (App Store requirement)',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final password = await showDeleteAccountDialog(context);
                          if (!context.mounted || password == null) return;
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .deleteAccount(password);
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  trEn(
                                    context,
                                    'Hesabın kapatıldı.',
                                    'Your account was closed.',
                                  ),
                                ),
                              ),
                            );
                          } else {
                            final err =
                                ref.read(authControllerProvider).errorMessage;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.logout_rounded,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          trEn(context, 'Çıkış yap', 'Log out'),
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          trEn(
                            context,
                            'Bu cihazdaki oturumu kapat',
                            'End session on this device',
                          ),
                        ),
                        onTap: () async {
                          final ok = await showLogoutConfirmDialog(context);
                          if (ok && context.mounted) {
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

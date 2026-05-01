import 'package:flutter/material.dart';

import '../locale/locale_text.dart';

/// App Store 1.4.x — profesyonel sağlık hizmeti olmadığı ve acil durum yönlendirmesi.
class HealthDisclaimerScreen extends StatelessWidget {
  const HealthDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          trEn(context, 'Sağlık ve destek', 'Health and support'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            trEn(
              context,
              'Önemli bilgilendirme',
              'Important information',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            trEn(
              context,
              'Rahatla, tıbbi teşhis, tedavi veya profesyonel terapi hizmeti sunmaz. '
              'Uygulamadaki dinleyenler sertifikalı klinik psikolog veya psikiyatrist değildir; '
              'sohbetler destek ve dinleme odaklıdır.',
              'Rahatla does not provide medical diagnosis, treatment, or professional therapy. '
              'Listeners in the app are not licensed clinical psychologists or psychiatrists; '
              'conversations are focused on support and listening.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            trEn(context, 'Acil durum', 'Emergency'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trEn(
              context,
              'Kendine veya başkasına zarar verme riski, intihar düşüncesi veya acil tıbbi '
              'durum hissediyorsan derhal yerel acil hattı veya 112’yi ara. '
              'Türkiye’de zor anlarda 182 Sosyal Destek Hattı da danışma için kullanılabilir.',
              'If you feel at risk of harming yourself or others, have thoughts of suicide, or '
              'are in a medical emergency, call your local emergency number or 112 immediately. '
              'In Turkey, the 182 Social Support Line can also be used in difficult times.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            trEn(
              context,
              'Bu metin genel bilgilendirme amaçlıdır; hukuki danışmanlık değildir.',
              'This text is for general information only; it is not legal advice.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// App Store 1.2 — UGC / topluluk kuralları (uygulama içi erişilebilir metin).
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bullets = <(String, String)>[
      (
        'Saygılı ve güvenli iletişim: taciz, tehdit, nefret söylemi ve zorbalık yasaktır.',
        'Respectful, safe communication: harassment, threats, hate speech, and bullying are not allowed.',
      ),
      (
        'Yasadışı içerik, dolandırıcılık veya başkasının zararına yönelik davranışlar yasaktır.',
        'Illegal content, fraud, or behavior intended to harm others is not allowed.',
      ),
      (
        'Kişisel verileri (adres, şifre vb.) paylaşmaktan kaçın; başkasının gizliliğine saygı göster.',
        'Avoid sharing personal data (address, passwords, etc.); respect other people’s privacy.',
      ),
      (
        'Şüpheli veya rahatsız edici davranışlarda sohbet menüsünden şikayet edebilir veya kullanıcıyı engelleyebilirsin.',
        'If someone behaves suspiciously or inappropriately, you can report them from the chat menu or block the user.',
      ),
      (
        'Moderasyon ihlallerinde hesap kısıtlaması veya kapatma uygulanabilir.',
        'Moderation may restrict or close accounts for violations.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          trEn(context, 'Topluluk kuralları', 'Community guidelines'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            trEn(
              context,
              'Rahatla’da herkesin güvenli hissetmesi için aşağıdaki kurallara uyulması beklenir.',
              'Everyone is expected to follow the rules below so that Rahatla feels safe for all.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (pair) {
              final t = trEn(context, pair.$1, pair.$2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodyLarge),
                    Expanded(
                      child: Text(
                        t,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tam gizlilik politikası URL’i yokken mağaza incelemesi için özet (5.1.1 tamamlayıcı).
class PrivacyOverviewScreen extends StatelessWidget {
  const PrivacyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          trEn(context, 'Gizlilik özeti', 'Privacy overview'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            trEn(
              context,
              'Bu özet bilgilendirme amaçlıdır. Resmi metin için mağaza kaydında verdiğiniz '
              'Gizlilik Politikası bağlantısını kullanın; mümkünse derlemede '
              'LEGAL_PRIVACY_URL tanımlayıp uygulamadan da açın.',
              'This summary is for information only. For the official text, use the Privacy Policy '
              'link in your store listing; where possible, define LEGAL_PRIVACY_URL in the build and open it from the app as well.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            trEn(
              context,
              'İşlenen veri örnekleri',
              'Examples of data processed',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trEn(
              context,
              'Hesap (e-posta, profil), oturum ve mesaj içerikleri, ruh hali tercihleri, '
              'bildirimler, cihazla ilgili teknik veriler (güvenli oturum için) ve '
              'isteğe bağlı profil fotoğrafı yüklemesi.',
              'Account (email, profile), session and message content, mood preferences, '
              'notifications, device-related technical data (for a secure session), and '
              'optional profile photo upload.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            trEn(context, 'Amaçlar', 'Purposes'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trEn(
              context,
              'Hizmeti sunmak, güvenliği sağlamak (şikayet/engel), yasal yükümlülükler ve '
              'destek taleplerini yürütmek.',
              'To provide the service, maintain safety (reports/blocks), meet legal obligations, and '
              'handle support requests.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Mağaza listesi ve harici gizlilik metni için isteğe bağlı HTTPS adresleri.
/// Derleme: `--dart-define=LEGAL_PRIVACY_URL=https://...`
class LegalUrls {
  LegalUrls._();

  static const String privacyPolicy = String.fromEnvironment(
    'LEGAL_PRIVACY_URL',
    defaultValue: '',
  );

  static const String termsOfService = String.fromEnvironment(
    'LEGAL_TERMS_URL',
    defaultValue: '',
  );

  static bool get hasPrivacyUrl =>
      privacyPolicy.trim().isNotEmpty && _looksLikeUrl(privacyPolicy);

  static bool get hasTermsUrl =>
      termsOfService.trim().isNotEmpty && _looksLikeUrl(termsOfService);

  static bool _looksLikeUrl(String s) {
    final u = Uri.tryParse(s.trim());
    return u != null &&
        u.hasScheme &&
        (u.scheme == 'https' || u.scheme == 'http');
  }
}

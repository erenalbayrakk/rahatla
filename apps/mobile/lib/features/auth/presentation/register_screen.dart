import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/storage/local_cache_provider.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../../shared/widgets/calm_text_field.dart';
import '../../../shared/widgets/soft_header.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

String _contentTypeForImagePath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _name = TextEditingController();
  var _acceptTerms = false;
  var _readTerms = false;
  var _readPrivacy = false;
  var _preferAnonymous = false;
  var _loading = false;
  var _themeMode = ThemeMode.system;
  XFile? _selfie;
  /// Kullanıcı uyarı diyaloğunda onayladıysa selfie olmadan devam edebilir.
  var _selfieSkipAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ref.read(appThemeModeProvider);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) {
      return trEn(context, 'E-posta gerekli', 'Email is required');
    }
    if (!s.contains('@')) {
      return trEn(context, 'Geçerli bir e-posta gir', 'Enter a valid email');
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    if ((v ?? '').length < 8) {
      return trEn(context, 'En az 8 karakter', 'At least 8 characters');
    }
    return null;
  }

  String? _password2Validator(String? v) {
    if (v != _password.text) {
      return trEn(context, 'Şifreler eşleşmiyor', 'Passwords do not match');
    }
    return _passwordValidator(v);
  }

  Future<void> _pickSelfie(ImageSource source) async {
    final f = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (f != null) {
      setState(() {
        _selfie = f;
        _selfieSkipAcknowledged = false;
      });
      await ref.read(localCacheServiceProvider).setSelfieStepSkipped(false);
    }
  }

  Future<void> _pickSelfieCamera() => _pickSelfie(ImageSource.camera);

  Future<void> _onSkipSelfie() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            trEn(ctx, 'Selfie olmadan devam', 'Continue without a selfie'),
          ),
          content: Text(
            trEn(
              ctx,
              "Doğrulama selfie'si eklemezseniz güvenilirliğiniz azalacaktır. "
              'Şimdilik yoksaymak istediğinize emin misiniz?',
              'Without a verification selfie, your trust score will be lower. '
              'Are you sure you want to skip for now?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(trEn(ctx, 'Geri dön', 'Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                trEn(ctx, 'Şimdilik yoksay', 'Skip for now'),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      setState(() {
        _selfieSkipAcknowledged = true;
        _selfie = null;
      });
      await ref.read(localCacheServiceProvider).setSelfieStepSkipped(true);
      await ref.read(localCacheServiceProvider).setSelfieStepCompleted(true);
    }
  }

  Future<void> _submit() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Devam etmek için şartları onayla.', 'Accept the terms to continue.'),
          ),
        ),
      );
      return;
    }
    if (_selfie == null && !_selfieSkipAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Selfie çek veya «Şimdilik yoksay» ile devam etmeyi onayla.',
              'Take a selfie or confirm continuing with "Skip for now".',
            ),
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref.read(localCacheServiceProvider).setSelfieStepCompleted(false);
    ref.read(authControllerProvider.notifier).clearError();
    await ref.read(authControllerProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          preferAnonymous: _preferAnonymous,
        );
    if (!mounted) return;
    final err = ref.read(authControllerProvider).errorMessage;
    if (err != null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    var selfieUploaded = false;
    if (_selfie != null) {
      try {
        final file = _selfie!;
        final bytes = await file.readAsBytes();
        final fn = file.name.isNotEmpty ? file.name : 'selfie.jpg';
        final ct = file.mimeType ?? _contentTypeForImagePath(file.path);
        await ref.read(authRepositoryProvider).uploadVerifySelfie(
              bytes: bytes,
              filename: fn,
              contentType: ct,
            );
        await ref.read(localCacheServiceProvider).setSelfieStepSkipped(false);
        await ref.read(localCacheServiceProvider).setSelfieStepCompleted(true);
        await ref.read(authControllerProvider.notifier).refreshUser();
        selfieUploaded = true;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trEn(
                context,
                'Hesap oluştu ancak selfie yüklenemedi: ${e.message}. Profilden tekrar deneyebilirsin.',
                'Account was created but the selfie could not be uploaded: ${e.message}. You can try again from your profile.',
              ),
            ),
          ),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trEn(context, 'Selfie yüklenemedi: $e', 'Selfie could not be uploaded: $e'),
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selfieUploaded
              ? trEn(
                  context,
                  'Kayıt tamam. Selfie yüklendi ve admin onay kuyruğuna alındı.',
                  'All set. Your selfie was uploaded and queued for review.',
                )
              : trEn(
                  context,
                  'Kayıt tamam. E-postana bir doğrulama bağlantısı gönderdik; gelen kutunu kontrol et.',
                  'All set. We sent a verification link to your email; check your inbox.',
                ),
        ),
      ),
    );
  }

  Future<bool> _showLegalSheet({
    required String title,
    required String content,
  }) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx);
        final ctrl = ScrollController();
        var canConfirm = false;

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            void updateCanConfirm() {
              if (!ctrl.hasClients) return;
              final atEnd =
                  ctrl.position.pixels >= ctrl.position.maxScrollExtent - 8;
              if (atEnd != canConfirm) {
                setLocalState(() => canConfirm = atEnd);
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) => updateCanConfirm());

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) {
                            updateCanConfirm();
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: ctrl,
                            child: Text(
                              content,
                              style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: canConfirm ? () => Navigator.of(ctx).pop(true) : null,
                        child: Text(
                          trEn(ctx, 'Okudum, tamam', 'I have read, OK'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canConfirm
                            ? trEn(ctx, 'Tamamlandı.', 'Done.')
                            : trEn(
                                ctx,
                                'Devam etmek için metni en alta kadar kaydır.',
                                'Scroll to the bottom to continue.',
                              ),
                        textAlign: TextAlign.center,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return done == true;
  }

  static const _termsMockText =
      'KULLANIM KOŞULLARI\n\n'
      '1) Uygulamayı yasalara ve topluluk kurallarına uygun kullanmayı kabul edersin.\n\n'
      '2) Hakaret, tehdit, taciz, dolandırıcılık, spam ve benzeri kötüye kullanım yasaktır.\n\n'
      '3) Hesap güvenliği kullanıcı sorumluluğundadır; şifreni üçüncü kişilerle paylaşmamalısın.\n\n'
      '4) Uygulama içi özellikler ve içerikler hizmet kalitesini korumak için güncellenebilir.\n\n'
      '5) İhlal durumunda hesabın kısıtlanabilir veya kapatılabilir.\n\n'
      '6) Dijital satın alımlar ilgili mağaza kurallarına (App Store / Play Store) tabidir.\n\n'
      '7) Uygulamayı kullanarak bu koşulları okuduğunu ve kabul ettiğini beyan edersin.\n';

  static const _privacyMockText =
      'GİZLİLİK POLİTİKASI\n\n'
      '1) Hesap oluşturma ve güvenlik için gerekli temel veriler işlenir.\n\n'
      '2) Sohbet ve profil verileri hizmetin sunulması, güvenlik ve moderasyon amacıyla tutulabilir.\n\n'
      '3) Kimlik doğrulama selfie verisi yalnızca doğrulama ve güvenlik süreçlerinde kullanılır.\n\n'
      '4) Yetkisiz erişimi önlemek için teknik ve idari güvenlik önlemleri uygulanır.\n\n'
      '5) Yasal zorunluluklar haricinde kişisel veriler izinsiz üçüncü taraflara satılmaz.\n\n'
      '6) Kullanıcı, mevzuata uygun olarak verilerine ilişkin erişim/düzeltme/silme taleplerinde bulunabilir.\n\n'
      '7) Politikada yapılan güncellemeler uygulama içinde duyurulabilir.\n';

  static const _termsMockTextEn =
      'TERMS OF USE\n\n'
      '1) You agree to use the app in compliance with applicable laws and community rules.\n\n'
      '2) Harassment, threats, abuse, fraud, spam, and similar misuse are prohibited.\n\n'
      '3) You are responsible for your account; do not share your password with others.\n\n'
      '4) In-app features and content may be updated to maintain service quality.\n\n'
      '5) Your account may be limited or closed in case of violations.\n\n'
      '6) Digital purchases are subject to the relevant store rules (App Store / Play Store).\n\n'
      '7) By using the app, you state that you have read and accept these terms.\n';

  static const _privacyMockTextEn =
      'PRIVACY POLICY\n\n'
      '1) Basic data required for account creation and security is processed.\n\n'
      '2) Chat and profile data may be kept for service delivery, security, and moderation.\n\n'
      '3) Identity verification selfie data is used only for verification and security.\n\n'
      '4) Technical and organizational safeguards are applied to prevent unauthorized access.\n\n'
      '5) Personal data is not sold to third parties without consent, except where required by law.\n\n'
      '6) You may request access, correction, or deletion in line with applicable laws.\n\n'
      '7) Policy updates may be announced in the app.\n';

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
                title: trEn(context, 'Hesap oluştur', 'Create account'),
                subtitle: trEn(context, 'Birkaç bilgi yeterli', 'Just a few details'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 8),
              CalmTextField(
                controller: _email,
                label: trEn(context, 'E-posta', 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _name,
                label: trEn(context, 'Görünen ad (isteğe bağlı)', 'Display name (optional)'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _password,
                label: trEn(context, 'Şifre', 'Password'),
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: _passwordValidator,
              ),
              const SizedBox(height: 16),
              CalmTextField(
                controller: _password2,
                label: trEn(context, 'Şifre tekrar', 'Password again'),
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: _password2Validator,
              ),
              const SizedBox(height: 20),
              Text(
                trEn(context, "Doğrulama selfie'si", 'Verification selfie'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                trEn(
                  context,
                  'Yüzünü gösteren bir fotoğraf güvenilirliğini artırır. İstersen şimdilik yoksayabilirsin.',
                  'A clear photo of your face increases trust. You can skip for now.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickSelfieCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: Text(trEn(context, 'Kamerayla çek', 'Take with camera')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _onSkipSelfie,
                child: Text(trEn(context, 'Şimdilik yoksay', 'Skip for now')),
              ),
              if (_selfieSkipAcknowledged && _selfie == null) ...[
                const SizedBox(height: 4),
                Text(
                  trEn(
                    context,
                    'Selfie atlandı; güvenilirliğin azalabilir.',
                    'Selfie skipped; your trust may be lower.',
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
              if (_selfie != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trEn(context, 'Selfie eklendi.', 'Selfie added.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                trEn(context, 'Görünüm', 'Appearance'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text(trEn(context, 'Açık', 'Light')),
                    icon: const Icon(Icons.light_mode_outlined, size: 18),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text(trEn(context, 'Koyu', 'Dark')),
                    icon: const Icon(Icons.dark_mode_outlined, size: 18),
                  ),
                ],
                selected: {_themeMode == ThemeMode.system ? ThemeMode.dark : _themeMode},
                onSelectionChanged: (s) async {
                  if (s.isEmpty) return;
                  final next = s.first;
                  setState(() => _themeMode = next);
                  await ref.read(appThemeModeProvider.notifier).setThemeMode(next);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _preferAnonymous,
                onChanged: (v) => setState(() => _preferAnonymous = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  trEn(context, 'Anonim görünüm', 'Anonymous mode'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _preferAnonymous
                      ? trEn(
                          context,
                          'Açık: dinleyenlerde ve grup sohbetinde adın gizlenir.',
                          'On: your name is hidden to listeners and in group chat.',
                        )
                      : trEn(
                          context,
                          'Kapalı: görünen adın gösterilir.',
                          'Off: your display name is shown.',
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trEn(
                          context,
                          'Sonradan profilden değiştirebilirsin.',
                          'You can change this later in your profile.',
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (v) {
                      if (!_readTerms || !_readPrivacy) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              trEn(
                                context,
                                'Önce Kullanım Koşulları ve Gizlilik Politikası metinlerini tamamla.',
                                'Complete the Terms and Privacy Policy scroll-through first.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _acceptTerms = v ?? false);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            onTap: _loading
                                ? null
                                : () async {
                                    final done = await _showLegalSheet(
                                      title: trEn(
                                        context,
                                        'Kullanım Koşulları',
                                        'Terms of Use',
                                      ),
                                      content: isEnglishLocale(context)
                                          ? _termsMockTextEn
                                          : _termsMockText,
                                    );
                                    if (!mounted || !done) return;
                                    setState(() => _readTerms = true);
                                  },
                            child: Text(
                              _readTerms
                                  ? trEn(
                                      context,
                                      'Kullanım Koşulları ✓',
                                      'Terms of use ✓',
                                    )
                                  : trEn(
                                      context,
                                      'Kullanım Koşulları',
                                      'Terms of use',
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            trEn(context, ' ve ', ' and '),
                            style: theme.textTheme.bodySmall,
                          ),
                          InkWell(
                            onTap: _loading
                                ? null
                                : () async {
                                    final done = await _showLegalSheet(
                                      title: trEn(
                                        context,
                                        'Gizlilik Politikası',
                                        'Privacy Policy',
                                      ),
                                      content: isEnglishLocale(context)
                                          ? _privacyMockTextEn
                                          : _privacyMockText,
                                    );
                                    if (!mounted || !done) return;
                                    setState(() => _readPrivacy = true);
                                  },
                            child: Text(
                              _readPrivacy
                                  ? trEn(
                                      context,
                                      'Gizlilik Politikası ✓',
                                      'Privacy policy ✓',
                                    )
                                  : trEn(
                                      context,
                                      'Gizlilik Politikası',
                                      'Privacy policy',
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            trEn(
                              context,
                              "'nı okudum ve kabul ediyorum.",
                              ' I have read and accept.',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!_readTerms || !_readPrivacy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    trEn(
                      context,
                      'Devam için iki metni de popup içinde en alta kadar kaydırıp tamamla.',
                      'Scroll both documents to the bottom in the pop-up to continue.',
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_selfieSkipAcknowledged && _selfie == null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEACB64)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF9A6D00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trEn(
                            context,
                            'Selfie atlandı. Profilinden sonradan ekleyebilirsin.',
                            'Selfie skipped. You can add it later from your profile.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6C4B00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              CalmCTAButton(
                label: trEn(context, 'Devam et', 'Continue'),
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pushReplacement(RoutePaths.login),
                child: Text(trEn(context, 'Girişe dön', 'Back to sign in')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

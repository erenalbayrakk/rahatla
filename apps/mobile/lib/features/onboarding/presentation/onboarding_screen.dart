import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';

String _contentTypeForImagePath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _kMaxProfilePhotos = 6;
  final _controller = PageController();
  final _picker = ImagePicker();
  var _page = 0;
  XFile? _selfie;
  List<XFile> _profilePhotos = <XFile>[];
  var _selfieUploading = false;
  var _profilePhotosUploading = false;
  var _selfieStepSkipped = false;
  var _selfieStepCompleted = false;

  List<_OnbPage> _pagesList(BuildContext context) => [
    _OnbPage(
      title: trEn(context, 'Önce sınırlar', 'Boundaries first'),
      body: trEn(
        context,
        'Rahatla kriz hattı veya terapi yerine geçmez. Zor anlarında lütfen yerel destek hatlarına başvur.',
        'Rahatla is not a crisis line or therapy. In difficult moments, please contact local support services.',
      ),
      icon: Icons.health_and_safety_outlined,
    ),
    _OnbPage(
      title: trEn(context, 'Güvenli alan', 'A safe space'),
      body: trEn(
        context,
        'Kişisel bilgi paylaşmak zorunda değilsin. Rahatsız olduğunda raporla veya engelle — tek dokunuşla.',
        "You are not required to share personal data. If you feel unsafe, report or block — one tap.",
      ),
      icon: Icons.verified_user_outlined,
    ),
    _OnbPage(
      title: trEn(context, 'Nasıl ilerler?', 'How it works'),
      body: trEn(
        context,
        'Destek isteğini aç, uygun bir dinleyenle eşleş, yazılı veya sesli görüş. Her şey kurallar çerçevesinde.',
        'Open a support request, match with a listener, chat or call — all within the community rules.',
      ),
      icon: Icons.route_outlined,
    ),
    _OnbPage(
      title: trEn(context, "Doğrulama selfie'si", 'Verification selfie'),
      body: trEn(
        context,
        "Kamerayla çekebilirsin; güvenilirliğini artırır. İstersen şimdilik yoksayabilirsin (güvenilirliğin azalır).",
        'You can use the camera; it increases trust. You can skip for now (with lower trust).',
      ),
      icon: Icons.face_retouching_natural_outlined,
      isSelfie: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).refreshUser();
      _selfieStepSkipped = ref.read(localCacheServiceProvider).selfieStepSkipped;
      _selfieStepCompleted =
          ref.read(localCacheServiceProvider).selfieStepCompleted;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasVerifySelfie() {
    final u = ref.read(authControllerProvider).user;
    final a = u?.verifySelfieUrl;
    return a != null && a.isNotEmpty;
  }

  Future<void> _pickSelfieCamera() async {
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (f != null) {
      await ref.read(localCacheServiceProvider).setSelfieStepSkipped(false);
      setState(() {
        _selfie = f;
        _selfieStepSkipped = false;
      });
    }
  }

  Future<void> _pickProfileImages() async {
    final existing =
        ref.read(authControllerProvider).user?.profileImageUrls.length ?? 0;
    final room = (_kMaxProfilePhotos - existing - _profilePhotos.length)
        .clamp(0, _kMaxProfilePhotos);
    if (room <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'En fazla 6 profil görseli ekleyebilirsin.',
              'You can add at most 6 profile photos.',
            ),
          ),
        ),
      );
      return;
    }
    final list = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (list.isEmpty || !mounted) return;
    setState(() {
      final take = list.take(room);
      _profilePhotos = [..._profilePhotos, ...take];
    });
  }

  void _removePendingProfilePhotoAt(int index) {
    if (index < 0 || index >= _profilePhotos.length) return;
    setState(() {
      final next = [..._profilePhotos]..removeAt(index);
      _profilePhotos = next;
    });
  }

  Future<bool> _uploadPendingProfilePhotos() async {
    if (_profilePhotos.isEmpty) return true;
    final auth = ref.read(authControllerProvider);
    final existing = auth.user?.profileImageUrls ?? const <String>[];
    final room = _kMaxProfilePhotos - existing.length;
    if (room <= 0) return true;

    setState(() => _profilePhotosUploading = true);
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      final toUpload = _profilePhotos.take(room).toList();
      final uploadedUrls = <String>[];
      for (final photo in toUpload) {
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty) continue;
        final url = await notifier.uploadProfileImage(
          bytes: bytes,
          filename: photo.name,
          contentType: photo.mimeType ?? _contentTypeForImagePath(photo.path),
        );
        if (url != null && url.isNotEmpty) {
          uploadedUrls.add(url);
        }
      }
      if (uploadedUrls.isEmpty) {
        final err = ref.read(authControllerProvider).errorMessage;
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        return false;
      }
      final next = [...existing, ...uploadedUrls].take(_kMaxProfilePhotos).toList();
      final ok = await notifier.updateProfileImages(next);
      if (!ok) {
        final err = ref.read(authControllerProvider).errorMessage;
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        return false;
      }
      if (mounted) {
        setState(() => _profilePhotos = <XFile>[]);
      }
      return true;
    } finally {
      if (mounted) setState(() => _profilePhotosUploading = false);
    }
  }

  Future<void> _onSkipSelfieOnboarding() async {
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
              'Without a verification selfie, your trust score will be lower. Skip for now?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(trEn(ctx, 'Geri dön', 'Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(trEn(ctx, 'Şimdilik yoksay', 'Skip for now')),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await ref.read(localCacheServiceProvider).setSelfieStepSkipped(true);
      await ref.read(localCacheServiceProvider).setSelfieStepCompleted(true);
      setState(() {
        _selfieStepSkipped = true;
        _selfieStepCompleted = true;
      });
      await ref.read(authControllerProvider.notifier).completeOnboarding();
    }
  }

  Future<void> _next() async {
    final pages = _pagesList(context);
    if (_page < pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (_hasVerifySelfie() || _selfieStepSkipped || _selfieStepCompleted) {
      final photosOk = await _uploadPendingProfilePhotos();
      if (!photosOk) return;
      await ref.read(authControllerProvider.notifier).completeOnboarding();
      return;
    }

    if (_selfie == null) {
      if (!mounted) return;
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

    setState(() => _selfieUploading = true);
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
      final photosOk = await _uploadPendingProfilePhotos();
      if (!photosOk) return;
      await ref.read(authControllerProvider.notifier).completeOnboarding();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _selfieUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = _pagesList(context);
    final lastPage = _page == pages.length - 1;
    final busy = _selfieUploading || _profilePhotosUploading;

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final p = pages[i];
                if (p.isSelfie) {
                  final u = ref.watch(authControllerProvider).user;
                  final verifyUrl = u?.verifySelfieUrl;
                  final existingProfileUrls =
                      u?.profileImageUrls ?? const <String>[];
                  final has = verifyUrl != null && verifyUrl.isNotEmpty;
                  return _SelfiePageContent(
                    hasVerifySelfie: has,
                    verifySelfieUrl: verifyUrl,
                    selfie: _selfie,
                    existingProfileImageUrls: existingProfileUrls,
                    profilePhotos: _profilePhotos,
                    onPickCamera: _pickSelfieCamera,
                    onPickProfileImages: _pickProfileImages,
                    onRemoveProfilePhotoAt: _removePendingProfilePhotoAt,
                    onSkipSelfie: _onSkipSelfieOnboarding,
                    theme: theme,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 28, 4, 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                p.icon,
                                size: 28,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            p.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            p.body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          CalmCTAButton(
            label: lastPage
                ? (_hasVerifySelfie() ||
                        _selfieStepSkipped ||
                        _selfieStepCompleted
                    ? trEn(context, 'Anladım, devam et', 'Got it, continue')
                    : trEn(
                        context,
                        'Selfieyi kaydet ve devam et',
                        'Save selfie and continue',
                      ))
                : trEn(context, 'İleri', 'Next'),
            isLoading: busy,
            onPressed: _next,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SelfiePageContent extends StatelessWidget {
  const _SelfiePageContent({
    required this.hasVerifySelfie,
    required this.verifySelfieUrl,
    required this.selfie,
    required this.existingProfileImageUrls,
    required this.profilePhotos,
    required this.onPickCamera,
    required this.onPickProfileImages,
    required this.onRemoveProfilePhotoAt,
    required this.onSkipSelfie,
    required this.theme,
  });

  final bool hasVerifySelfie;
  final String? verifySelfieUrl;
  final XFile? selfie;
  final List<String> existingProfileImageUrls;
  final List<XFile> profilePhotos;
  final Future<void> Function() onPickCamera;
  final Future<void> Function() onPickProfileImages;
  final void Function(int index) onRemoveProfilePhotoAt;
  final Future<void> Function() onSkipSelfie;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final existingCount = existingProfileImageUrls.length.clamp(0, 6);
    final totalCount = (existingCount + profilePhotos.length).clamp(0, 6);
    final canPickMore = totalCount < 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.face_retouching_natural_outlined,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                trEn(
                  context,
                  "Doğrulama selfie'si",
                  'Verification selfie',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                trEn(
                  context,
                  "Kamerayla çekebilirsin; güvenilirliğini artırır. "
                  "İstersen şimdilik yoksayabilirsin (güvenilirliğin azalır).",
                  "You can use the camera; it increases trust. "
                  "You can skip for now (with lower trust).",
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              if (hasVerifySelfie &&
                  verifySelfieUrl != null &&
                  verifySelfieUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      verifySelfieUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trEn(
                    context,
                    "Selfie kayıtlı. «Anladım, devam et» ile ilerleyebilirsin.",
                    "Selfie is saved. Tap 'Got it, continue' to proceed.",
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => onPickCamera(),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: Text(
                    trEn(context, 'Kamerayla çek', 'Take with camera'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => onSkipSelfie(),
                  child: Text(
                    trEn(context, 'Şimdilik yoksay', 'Skip for now'),
                  ),
                ),
                if (selfie != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.file(
                        File(selfie!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Text(
                trEn(context, 'Profil görselleri (en fazla 6)', 'Profile photos (up to 6)'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trEn(
                  context,
                  'Kütüphaneden görsel ekleyebilirsin. Profilden sonradan düzenleyebilirsin.',
                  'Add images from your library. You can edit them later in your profile.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in existingProfileImageUrls.take(6))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        u,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  for (var i = 0; i < profilePhotos.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(profilePhotos[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: InkWell(
                            onTap: () => onRemoveProfilePhotoAt(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (canPickMore)
                    OutlinedButton.icon(
                      onPressed: onPickProfileImages,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(trEn(context, 'Resim ekle', 'Add images')),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$totalCount/6',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnbPage {
  const _OnbPage({
    required this.title,
    required this.body,
    required this.icon,
    this.isSelfie = false,
  });
  final String title;
  final String body;
  final IconData icon;
  final bool isSelfie;
}

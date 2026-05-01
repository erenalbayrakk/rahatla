import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/mood/mood_catalog.dart';
import '../../../core/locale/locale_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/user/user_account_labels.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/delete_account_dialog.dart';
import '../../auth/presentation/logout_dialog.dart';
import '../../wallet/data/wallet_repository.dart';

/// Şampanya / brons ton — temadan bağımsız lüks vurgu (her iki modda okunur).
Color _luxAccentRing(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFD4C5AE)
      : const Color(0xFF7A6554);
}

class _ProfileAnonymousSwitch extends ConsumerStatefulWidget {
  const _ProfileAnonymousSwitch();

  @override
  ConsumerState<_ProfileAnonymousSwitch> createState() =>
      _ProfileAnonymousSwitchState();
}

class _ProfileDiscoverSwitch extends ConsumerStatefulWidget {
  const _ProfileDiscoverSwitch();

  @override
  ConsumerState<_ProfileDiscoverSwitch> createState() =>
      _ProfileDiscoverSwitchState();
}

class _ProfileDiscoverSwitchState extends ConsumerState<_ProfileDiscoverSwitch> {
  var _saving = false;

  Future<void> _set(bool visibleInDiscover) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateDiscoverVisibility(visibleInDiscover);
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visibleInDiscover
                ? trEn(
                    context,
                    'Keşfet listesinde ve aramalarda görüneceksin',
                    'You will appear in Discover and searches',
                  )
                : trEn(
                    context,
                    'Keşfet listesinden çıkarıldın',
                    'You are hidden from Discover',
                  ),
          ),
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = ref.watch(authControllerProvider).user?.visibleInDiscover ?? true;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        trEn(context, 'Keşfette görün', 'Show in Discover'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        trEn(
          context,
          'Kapalıysan dinleyen keşfet listesinde ve aramalarda çıkmazsın.',
          'When off, you will not appear in listener discover or search results.',
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
      value: on,
      onChanged: _saving ? null : _set,
    );
  }
}

class _ProfileThemeSwitch extends ConsumerStatefulWidget {
  const _ProfileThemeSwitch();

  @override
  ConsumerState<_ProfileThemeSwitch> createState() => _ProfileThemeSwitchState();
}

class _ProfileThemeSwitchState extends ConsumerState<_ProfileThemeSwitch> {
  var _saving = false;

  Future<void> _set(bool dark) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(appThemeModeProvider.notifier)
        .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(appThemeModeProvider);
    final dark = mode == ThemeMode.dark;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        trEn(context, 'Koyu tema', 'Dark theme'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        dark
            ? trEn(context, 'Koyu görünüm aktif.', 'Dark mode is on.')
            : trEn(context, 'Açık görünüm aktif.', 'Light mode is on.'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: dark,
      onChanged: _saving ? null : _set,
    );
  }
}

class _ProfileAnonymousSwitchState extends ConsumerState<_ProfileAnonymousSwitch> {
  var _saving = false;

  Future<void> _set(bool next) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updatePreferAnonymous(next);
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? trEn(
                    context,
                    'Anonim görünüm açık',
                    'Anonymous mode is on',
                  )
                : trEn(
                    context,
                    'Görünen adın diğer kullanıcılarla paylaşılacak',
                    'Your display name will be shared with others',
                  ),
          ),
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = ref.watch(authControllerProvider).user?.preferAnonymous ?? false;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        trEn(context, 'Şimdilik anonim kal', 'Stay anonymous for now'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        trEn(
          context,
          'Açıkken dinleyenler ve grup sohbetlerinde «Anonim kullanıcı» olarak görünürsün.',
          'When on, you appear as «Anonymous user» in listener and group chats.',
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
      value: on,
      onChanged: _saving ? null : _set,
    );
  }
}

class _ProfileMoodChips extends ConsumerStatefulWidget {
  const _ProfileMoodChips();

  @override
  ConsumerState<_ProfileMoodChips> createState() => _ProfileMoodChipsState();
}

class _ProfileMoodChipsState extends ConsumerState<_ProfileMoodChips> {
  var _saving = false;

  Future<void> _setMood(String? next) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await ref.read(authControllerProvider.notifier).updateMood(next);
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == null
                ? trEn(context, 'Ruh halin kaldırıldı', 'Your mood was cleared')
                : trEn(
                    context,
                    'Ruh halin kaydedildi — dinleyen listesinde kullanılır',
                    'Mood saved — used on the listener list',
                  ),
          ),
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(authControllerProvider).user?.moodCategory;
    final accent = _luxAccentRing(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LuxSectionTitle(
          label: trEn(context, 'Ruh halim', 'My mood'),
          hint: trEn(
            context,
            'Dinleyen listende filtre olarak kullanılır. Seçili çipe tekrar dokunarak temizle.',
            'Used as a filter on the listener list. Tap the selected chip again to clear.',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in MoodCatalog.options)
              _LuxMoodChip(
                option: o,
                selected: mood == o.apiValue,
                dimmed: _saving,
                accent: accent,
                onTap: () {
                  if (_saving) return;
                  if (mood == o.apiValue) {
                    _setMood(null);
                  } else {
                    _setMood(o.apiValue);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

const _kListenerAvailOptions = <MoodOption>[
  MoodOption(
    apiValue: 'available',
    label: 'Müsait',
    icon: Icons.check_circle_outline_rounded,
  ),
  MoodOption(
    apiValue: 'automatic',
    label: 'Otomatik',
    icon: Icons.bolt_outlined,
  ),
  MoodOption(
    apiValue: 'busy',
    label: 'Yoğun',
    icon: Icons.do_not_disturb_on_outlined,
  ),
];

class _ProfileListenerAvailabilityChips extends ConsumerStatefulWidget {
  const _ProfileListenerAvailabilityChips();

  @override
  ConsumerState<_ProfileListenerAvailabilityChips> createState() =>
      _ProfileListenerAvailabilityChipsState();
}

class _ProfileListenerAvailabilityChipsState
    extends ConsumerState<_ProfileListenerAvailabilityChips> {
  var _saving = false;

  Future<void> _setMode(String next) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateListenerAvailability(next);
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Müsaitlik durumun kaydedildi.',
              'Your availability was saved.',
            ),
          ),
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = ref.watch(authControllerProvider).user?.listenerAvailabilityMode;
    final mode = raw ?? 'available';
    final accent = _luxAccentRing(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LuxSectionTitle(
          label: trEn(context, 'Dinleyen durumum', 'Listener status'),
          hint: trEn(
            context,
            'Müsait: eşleşme havuzunda her zaman görünürsün. Otomatik: uygulama ve ayarlarına göre. Yoğun: havuzda görünmezsin.',
            'Available: always visible in the match pool. Automatic: based on app usage and settings. Busy: not shown in the pool.',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in _kListenerAvailOptions)
              _LuxMoodChip(
                option: o,
                selected: mode == o.apiValue,
                dimmed: _saving,
                accent: accent,
                onTap: () {
                  if (_saving || mode == o.apiValue) return;
                  _setMode(o.apiValue);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LuxSectionTitle extends StatelessWidget {
  const _LuxSectionTitle({
    required this.label,
    required this.hint,
  });

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary,
                    _luxAccentRing(context),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Üst kimlik özeti — tek kartta avatar, isim, rol rozetleri (Material 3 yüzey).
class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.initial,
    required this.displayName,
    required this.email,
    required this.kind,
    required this.verified,
    this.avatarUrl,
    this.profileImageUrls = const <String>[],
  });

  final String initial;
  final String displayName;
  final String email;
  final UserAccountKind? kind;
  final bool verified;
  final String? avatarUrl;
  final List<String> profileImageUrls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = _luxAccentRing(context);
    final photoUrl = () {
      final a = avatarUrl?.trim();
      if (a != null && a.isNotEmpty) return a;
      if (profileImageUrls.isNotEmpty) return profileImageUrls.first;
      return null;
    }();
    final surface = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.38 : 0.65,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.09),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ring,
                  theme.colorScheme.primary.withValues(alpha: 0.82),
                  ring.withValues(alpha: 0.5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.surface,
              child: CircleAvatar(
                radius: 41,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                onBackgroundImageError:
                    photoUrl != null ? (_, __) {} : null,
                child: photoUrl == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email.isEmpty ? '—' : email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.15,
            ),
          ),
          if (kind != null) ...[
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _AccountKindChip(kind: kind!),
                _VerifyChip(verified: verified),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                kind!.descriptionL10n(context),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _kMaxProfilePhotos = 6;

class _ProfilePhotoGallery extends ConsumerStatefulWidget {
  const _ProfilePhotoGallery();

  @override
  ConsumerState<_ProfilePhotoGallery> createState() =>
      _ProfilePhotoGalleryState();
}

class _ProfilePhotoGalleryState extends ConsumerState<_ProfilePhotoGallery> {
  final _picker = ImagePicker();
  var _busy = false;

  Future<void> _addPhoto() async {
    if (_busy) return;
    final user = ref.read(authControllerProvider).user;
    final cur = user?.profileImageUrls ?? [];
    if (cur.length >= _kMaxProfilePhotos) return;
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    if (bytes.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final url = await ref.read(authControllerProvider.notifier).uploadProfileImage(
          bytes: bytes,
          filename: x.name,
          contentType: x.mimeType ?? 'image/jpeg',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (url == null || url.isEmpty) {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    final next = [...cur, url];
    final ok =
        await ref.read(authControllerProvider.notifier).updateProfileImages(next);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Fotoğraf eklendi', 'Photo added'),
          ),
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  Future<void> _confirmRemove(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trEn(ctx, 'Fotoğrafı kaldır', 'Remove photo')),
        content: Text(
          trEn(
            ctx,
            'Bu görseli profilinden silmek istediğine emin misin?',
            'Remove this image from your profile?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(trEn(ctx, 'Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(trEn(ctx, 'Kaldır', 'Remove')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final cur = ref.read(authControllerProvider).user?.profileImageUrls ?? [];
    final next = cur.where((u) => u != url).toList();
    final success =
        await ref.read(authControllerProvider.notifier).updateProfileImages(next);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Fotoğraf kaldırıldı', 'Photo removed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = ref.watch(authControllerProvider).user?.profileImageUrls ?? [];
    final canAdd = urls.length < _kMaxProfilePhotos && !_busy;
    final itemCount = urls.length + (canAdd ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LuxSectionTitle(
          label: trEn(context, 'Profil fotoğrafları', 'Profile photos'),
          hint: trEn(
            context,
            'Görseller güvenli şekilde yüklenir ve profilinde saklanır. En fazla $_kMaxProfilePhotos fotoğraf ekleyebilirsin.',
            'Images are uploaded securely and stored on your profile. You can add up to $_kMaxProfilePhotos photos.',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i < urls.length) {
                final u = urls[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onLongPress: () => _confirmRemove(u),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      width: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.14),
                        ),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              u,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, prog) {
                                if (prog == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Material(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.92,
                                ),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _confirmRemove(u),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canAdd ? _addPhoto : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    width: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    ),
                    child: _busy
                        ? Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 30,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                trEn(context, 'Ekle', 'Add'),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
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
      ],
    );
  }
}

class _LuxMoodChip extends StatelessWidget {
  const _LuxMoodChip({
    required this.option,
    required this.selected,
    required this.dimmed,
    required this.accent,
    required this.onTap,
  });

  final MoodOption option;
  final bool selected;
  final bool dimmed;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: dimmed ? 0.98 : 1,
      duration: const Duration(milliseconds: 160),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: dimmed ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.surface.withValues(alpha: 0.92),
              border: Border.all(
                width: selected ? 1.5 : 1,
                color: selected
                    ? Color.lerp(theme.colorScheme.primary, accent, 0.35)!
                    : theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option.icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    MoodCatalog.labelLocalized(context, option.apiValue),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.2,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: selected ? 0.92 : 0.75,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxPanel extends StatelessWidget {
  const _LuxPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.55,
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: fill,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

class _LuxSettingsTile extends StatelessWidget {
  const _LuxSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileReceivedGiftsEntry extends ConsumerStatefulWidget {
  const _ProfileReceivedGiftsEntry();

  @override
  ConsumerState<_ProfileReceivedGiftsEntry> createState() =>
      _ProfileReceivedGiftsEntryState();
}

class _ProfileReceivedGiftsEntryState
    extends ConsumerState<_ProfileReceivedGiftsEntry> {
  var _loading = true;
  String? _error;
  ReceivedSessionGiftsResponseDto? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref
          .read(walletRepositoryProvider)
          .fetchReceivedSessionGifts(limit: 1);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _LuxPanel(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await context.push(RoutePaths.receivedGifts);
            if (mounted) await _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _luxAccentRing(context).withValues(alpha: 0.2),
                    border: Border.all(
                      color: _luxAccentRing(context).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.redeem_rounded,
                    color: _luxAccentRing(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trEn(context, 'Aldığın hediyeler', 'Received gifts'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_loading)
                        Text(
                          trEn(context, 'Yükleniyor…', 'Loading...'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        )
                      else if (_error != null)
                        Text(
                          trEn(
                            context,
                            'Gösterilemedi; dokunarak yeniden dene',
                            'Could not load; tap to retry',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.85,
                            ),
                            height: 1.3,
                          ),
                        )
                      else if (_data != null) ...[
                        Text(
                          _data!.giftCount == 0
                              ? trEn(context, 'Henüz hediye yok', 'No gifts yet')
                              : trEn(
                                  context,
                                  'Toplam net: ${_data!.totalRecipientEarnedMinor} birim · ${_data!.giftCount} hediye',
                                  'Total net: ${_data!.totalRecipientEarnedMinor} units · ${_data!.giftCount} gifts',
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.3,
                          ),
                        ),
                        if (_data!.giftCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            trEn(context, 'Detaylar için dokun', 'Tap for details'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnverifiedEmailBanner extends ConsumerStatefulWidget {
  const _UnverifiedEmailBanner();

  @override
  ConsumerState<_UnverifiedEmailBanner> createState() =>
      _UnverifiedEmailBannerState();
}

class _UnverifiedEmailBannerState extends ConsumerState<_UnverifiedEmailBanner> {
  var _sending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trEn(context, 'E-postanı doğrula', 'Verify your email'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trEn(
                context,
                'Gelen kutundaki bağlantıya tıkla veya yeni doğrulama e-postası iste.',
                'Open the link in your inbox or request a new verification email.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .resendVerificationMe();
                      if (mounted) setState(() => _sending = false);
                      if (!context.mounted) return;
                      final err = ref.read(authControllerProvider).errorMessage;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? trEn(
                                    context,
                                    'Doğrulama e-postası gönderildi.',
                                    'Verification email sent.',
                                  )
                                : (err ??
                                    trEn(
                                      context,
                                      'Gönderilemedi.',
                                      'Could not send.',
                                    )),
                          ),
                        ),
                      );
                    },
              child: Text(
                _sending
                    ? trEn(context, 'Gönderiliyor…', 'Sending…')
                    : trEn(
                        context,
                        'Doğrulama e-postasını tekrar gönder',
                        'Resend verification email',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFcmDebugCard extends ConsumerStatefulWidget {
  const _ProfileFcmDebugCard();

  @override
  ConsumerState<_ProfileFcmDebugCard> createState() => _ProfileFcmDebugCardState();
}

class _ProfileFcmDebugCardState extends ConsumerState<_ProfileFcmDebugCard> {
  String? _token;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _loadToken();
    if (!kIsWeb) {
      _sub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        if (!mounted) return;
        setState(() => _token = t);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadToken() async {
    if (kIsWeb) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (mounted) setState(() => _token = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = _token?.trim();
    final has = token != null && token.isNotEmpty;
    return _LuxPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trEn(context, 'Debug - FCM token', 'Debug - FCM token'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              (token != null && token.isNotEmpty)
                  ? token
                  : trEn(
                      context,
                      'Token henüz alınmadı.',
                      'Token not available yet.',
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: has
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: has
                      ? () async {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                trEn(
                                  context,
                                  'FCM token kopyalandı.',
                                  'FCM token copied.',
                                ),
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(trEn(context, 'Kopyala', 'Copy')),
                ),
                TextButton.icon(
                  onPressed: _loadToken,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(trEn(context, 'Yenile', 'Refresh')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final kind = user?.accountKind;
    final displayName = user?.email.split('@').first ??
        trEn(context, 'Kullanıcı', 'User');

    return AppScaffold(
      padding: EdgeInsets.zero,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.15, -0.2),
                    radius: 1.15,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.14),
                      theme.colorScheme.secondary.withValues(alpha: 0.06),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: AppSpacing.sliverT(top: 16, bottom: 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            trEn(context, 'Profilim', 'My profile'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trEn(
                              context,
                              'Hesabın, görünürlüğün ve ruh halin',
                              'Your account, visibility and mood',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (user != null && !user.isVerified) ...[
                      const _UnverifiedEmailBanner(),
                      const SizedBox(height: 24),
                    ],
                    if (user != null) ...[
                      _ProfileIdentityCard(
                        initial: initial,
                        displayName: displayName,
                        email: email,
                        kind: kind,
                        verified: user.isVerified,
                        avatarUrl: user.avatarUrl,
                        profileImageUrls: user.profileImageUrls,
                      ),
                      const SizedBox(height: AppSpacing.section),
                      const _ProfilePhotoGallery(),
                      const SizedBox(height: AppSpacing.section),
                      _LuxSectionTitle(
                        label: trEn(context, 'Hediyeler', 'Gifts'),
                        hint: trEn(
                          context,
                          'Birebir sohbetlerde sana gönderilen sanal hediyeler.',
                          'Virtual gifts sent to you in one-on-one chats.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ProfileReceivedGiftsEntry(),
                      const SizedBox(height: AppSpacing.section),
                    ],
                    _LuxPanel(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                        child: const _ProfileMoodChips(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    if (user != null) ...[
                      _LuxSectionTitle(
                        label: trEn(context, 'Görünürlük', 'Visibility'),
                        hint: trEn(
                          context,
                          'Anonim adın ve keşfet listesinde görünüp görünmeyeceğin.',
                          'Your anonymous name and whether you appear in Discover.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LuxPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _ProfileAnonymousSwitch(),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            const _ProfileDiscoverSwitch(),
                          ],
                        ),
                      ),
                    ],
                    if (user != null &&
                        (user.role == 'approved_listener' ||
                            user.role == 'admin')) ...[
                      const SizedBox(height: AppSpacing.section),
                      _LuxPanel(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                          child: const _ProfileListenerAvailabilityChips(),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    _LuxSectionTitle(
                      label: trEn(context, 'Hesap', 'Account'),
                      hint: trEn(context, 'Uygulama ayarları ve güvenlik', 'App settings and security'),
                    ),
                    const SizedBox(height: 12),
                    _LuxPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _ProfileThemeSwitch(),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          _LuxSettingsTile(
                            icon: Icons.tune_rounded,
                            title: trEn(context, 'Ayarlar', 'Settings'),
                            subtitle: trEn(context, 'Bildirimler, gizlilik ve destek', 'Notifications, privacy and support'),
                            onTap: () => context.push(RoutePaths.settings),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          _LuxSettingsTile(
                            icon: Icons.shield_outlined,
                            title: trEn(context, 'Güvenlik ve kurallar', 'Safety and rules'),
                            subtitle: trEn(context, 'Güvenli kullanım ve topluluk kuralları', 'Safe usage and community rules'),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(trEn(context, 'Güvenlik merkezi yakında.', 'Safety center coming soon.'))),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    _LuxSectionTitle(
                      label: trEn(context, 'Debug', 'Debug'),
                      hint: trEn(
                        context,
                        'Test push için FCM token kopyalama',
                        'Copy FCM token for test push',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ProfileFcmDebugCard(),
                    const SizedBox(height: 28),
                    _LuxSectionTitle(
                      label: trEn(context, 'Oturum', 'Session'),
                      hint: trEn(context, 'Bu cihazdaki oturumunu güvenle kapat', 'Safely close your session on this device'),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final ok = await showLogoutConfirmDialog(context);
                          if (ok && context.mounted) {
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
                          }
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.45,
                              ),
                              width: 1.25,
                            ),
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.05,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: theme.colorScheme.error,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                trEn(context, 'Çıkış yap', 'Log out'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final password = await showDeleteAccountDialog(context);
                          if (!context.mounted || password == null) return;
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .deleteAccount(password);
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(trEn(context, 'Hesabın kapatıldı.', 'Your account has been closed.'))),
                            );
                          } else {
                            final err = ref.read(authControllerProvider).errorMessage;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          }
                        },
                        child: Text(
                          trEn(context, 'Hesabı kalıcı olarak sil', 'Delete account permanently'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error.withValues(alpha: 0.9),
                            decoration: TextDecoration.underline,
                            decorationColor:
                                theme.colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountKindChip extends StatelessWidget {
  const _AccountKindChip({required this.kind});

  final UserAccountKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (kind) {
      UserAccountKind.helpSeeker => (
        theme.colorScheme.primary.withValues(alpha: 0.12),
        theme.colorScheme.primary,
      ),
      UserAccountKind.listenerApplicant => (
        theme.colorScheme.secondary.withValues(alpha: 0.16),
        theme.colorScheme.secondary,
      ),
      UserAccountKind.approvedListener => (
        theme.colorScheme.tertiary.withValues(alpha: 0.18),
        theme.colorScheme.tertiary,
      ),
      UserAccountKind.admin => (
        _luxAccentRing(context).withValues(alpha: 0.22),
        _luxAccentRing(context),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: fg.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        kind.titleL10n(context),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  const _VerifyChip({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ok
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.verified_outlined : Icons.mark_email_unread_outlined,
            size: 17,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            ok
                ? trEn(context, 'E-posta doğrulandı', 'Email verified')
                : trEn(context, 'E-posta bekleniyor', 'Email pending'),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: ok
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

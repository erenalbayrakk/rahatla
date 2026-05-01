import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
    required String role,
    @Default(false) bool isVerified,
    /// API `Gender` enum string veya null: female, male, non_binary, prefer_not_to_say
    String? gender,
    /// API `SupportCategory` veya null (profilde ruh hali).
    String? moodCategory,
    /// İsteğe bağlı profil avatarı (S3).
    String? avatarUrl,
    /// Doğrulama selfie'si; `avatarUrl` ile ayrı (S3 `verify_selfie_url`).
    String? verifySelfieUrl,
    /// Diğer kullanıcılara gerçek ad yerine anonim göster.
    @Default(false) bool preferAnonymous,
    /// Dinleyen keşfet listesi / aramada görünsün mü (`visible_in_discover`).
    @Default(true) bool visibleInDiscover,
    /// Profilde ek fotoğraflar (S3 URL listesi, `profile_image_urls`).
    @Default(<String>[]) List<String> profileImageUrls,
    /// Dinleyen için: `available` | `automatic` | `busy` (API snake_case).
    String? listenerAvailabilityMode,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final v = json['is_verified'] ?? json['isVerified'];
    final mood = json['mood_category'] ?? json['moodCategory'];
    final avail =
        json['listener_availability_mode'] ?? json['listenerAvailabilityMode'];
    final genderRaw = json['gender'];
    final avatar = json['avatar_url'] ?? json['avatarUrl'];
    final verify =
        json['verify_selfie_url'] ?? json['verifySelfieUrl'];
    final pa = json['prefer_anonymous'] ?? json['preferAnonymous'];
    final vid =
        json['visible_in_discover'] ?? json['visibleInDiscover'];
    final picsRaw = json['profile_image_urls'] ?? json['profileImageUrls'];
    final pics = <String>[];
    if (picsRaw is List) {
      for (final e in picsRaw) {
        if (e is String && e.trim().isNotEmpty) pics.add(e.trim());
      }
    }
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isVerified: v is bool ? v : false,
      gender: genderRaw is String ? genderRaw : null,
      moodCategory: mood is String ? mood : null,
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
      verifySelfieUrl:
          verify is String && verify.isNotEmpty ? verify : null,
      preferAnonymous: pa is bool ? pa : false,
      visibleInDiscover: vid is bool ? vid : true,
      profileImageUrls: pics,
      listenerAvailabilityMode: avail is String ? avail : null,
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_cache_provider.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureTokenStorageProvider),
    ref.watch(localCacheServiceProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._tokens, this._cache);

  final Dio _dio;
  final SecureTokenStorage _tokens;
  final LocalCacheService _cache;

  Future<AppUser> login(String email, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      await _persistAuthResponse(res.data!);
      final userJson = res.data!['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        throw ApiException('Sunucu yanıtı eksik (user).');
      }
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> register({
    required String email,
    required String password,
    String? displayName,
    bool preferAnonymous = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
          'preferAnonymous': preferAnonymous,
        },
      );
      await _persistAuthResponse(res.data!);
      await _cache.setOnboardingComplete(false);
      await _cache.setSelfieStepCompleted(false);
      await _cache.setSelfieStepSkipped(false);
      final userJson = res.data!['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        throw ApiException('Sunucu yanıtı eksik (user).');
      }
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Doğrulama selfie'si (S3 + `profiles.verify_selfie_url`; `avatar_url` değişmez).
  Future<String> uploadVerifySelfie({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/media/verify-selfie',
        data: form,
      );
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        throw ApiException('Yükleme yanıtı geçersiz.');
      }
      return url;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Profil galerisi görseli — S3 `profile-images/`. URL listesi için [updateProfileImages].
  Future<String> uploadProfileImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/media/profile-image',
        data: form,
      );
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        throw ApiException('Yükleme yanıtı geçersiz.');
      }
      return url;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> updateProfileImages(List<String> imageUrls) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me/profile-images',
        data: <String, dynamic>{'imageUrls': imageUrls},
      );
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> fetchMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> updatePreferAnonymous(bool preferAnonymous) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me/prefer-anonymous',
        data: <String, dynamic>{'preferAnonymous': preferAnonymous},
      );
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> updateDiscoverVisibility(bool visibleInDiscover) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me/discover-visibility',
        data: <String, dynamic>{'visibleInDiscover': visibleInDiscover},
      );
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> updateMood(String? moodCategory) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me/mood',
        data: <String, dynamic>{'moodCategory': moodCategory},
      );
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<void>(
        '/auth/forgot-password',
        data: <String, dynamic>{'email': email.trim()},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/reset-password',
        data: <String, dynamic>{
          'token': token.trim(),
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> verifyEmail(String token) async {
    try {
      await _dio.post<void>(
        '/auth/verify-email',
        data: <String, dynamic>{'token': token.trim()},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> resendVerificationByEmail(String email) async {
    try {
      await _dio.post<void>(
        '/auth/resend-verification',
        data: <String, dynamic>{'email': email.trim()},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> resendVerificationMe() async {
    try {
      await _dio.post<void>('/auth/me/resend-verification');
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      await _dio.post<void>(
        '/auth/me/delete-account',
        data: {'password': password},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AppUser> updateListenerAvailability(String availabilityMode) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me/listener-availability',
        data: <String, dynamic>{'availabilityMode': availabilityMode},
      );
      final data = res.data!;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return AppUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> _persistAuthResponse(Map<String, dynamic> body) async {
    final token =
        body['accessToken'] as String? ?? body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Sunucu yanıtı eksik (token).');
    }
    await _tokens.saveAccessToken(token);
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}

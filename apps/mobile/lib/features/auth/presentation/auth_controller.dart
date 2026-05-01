import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_cache_provider.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_repository.dart';
import '../data/logout_service.dart';
import '../domain/auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  LogoutService get _logout => ref.read(logoutServiceProvider);
  SecureTokenStorage get _tokens => ref.read(secureTokenStorageProvider);
  LocalCacheService get _cache => ref.read(localCacheServiceProvider);

  @override
  AuthState build() => const AuthState();

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.unknown, errorMessage: null);
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        onboardingComplete: _cache.onboardingComplete,
      );
      return;
    }
    try {
      final user = await _repo.fetchMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        onboardingComplete: _cache.onboardingComplete,
      );
    } on ApiException {
      await _tokens.clearAccessToken();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        onboardingComplete: _cache.onboardingComplete,
      );
    } catch (_) {
      await _tokens.clearAccessToken();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        onboardingComplete: _cache.onboardingComplete,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.login(email, password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        onboardingComplete: _cache.onboardingComplete,
      );
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
    bool preferAnonymous = false,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        preferAnonymous: preferAnonymous,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        onboardingComplete: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  Future<void> completeOnboarding() async {
    await _cache.setOnboardingComplete(true);
    state = state.copyWith(onboardingComplete: true);
  }

  Future<void> logout() async {
    await _logout.signOut();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      errorMessage: null,
      onboardingComplete: _cache.onboardingComplete,
    );
  }

  /// Sunucuda hesabı kapatır, tokenları siler ve oturumu düşürür.
  Future<bool> deleteAccount(String password) async {
    state = state.copyWith(errorMessage: null);
    try {
      await _repo.deleteAccount(password);
      await _logout.signOut();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: null,
        onboardingComplete: _cache.onboardingComplete,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(errorMessage: null);
    try {
      await _repo.forgotPassword(email);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      await _repo.resetPassword(token: token, password: password);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> verifyEmail(String token) async {
    state = state.copyWith(errorMessage: null);
    try {
      await _repo.verifyEmail(token);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> resendVerificationMe() async {
    state = state.copyWith(errorMessage: null);
    try {
      await _repo.resendVerificationMe();
      await refreshUser();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// `/auth/me` ile kullanıcıyı yeniler (ör. selfie yüklendikten sonra).
  Future<void> refreshUser() async {
    try {
      final user = await _repo.fetchMe();
      state = state.copyWith(user: user);
    } on ApiException {
      // Oturum düşmüş olabilir; restoreSession ile hizalanır
    }
  }

  Future<bool> updatePreferAnonymous(bool preferAnonymous) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.updatePreferAnonymous(preferAnonymous);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> updateDiscoverVisibility(bool visibleInDiscover) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.updateDiscoverVisibility(visibleInDiscover);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> updateProfileImages(List<String> imageUrls) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.updateProfileImages(imageUrls);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// S3 profil görseli yükler; URL’yi [updateProfileImages] ile listeye eklemelisin.
  Future<String?> uploadProfileImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      final url = await _repo.uploadProfileImage(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
      return url;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    }
  }

  /// Profilde görünen ruh hali. Aynı seçeneğe tekrar dokununca [clearMood] ile temizlenebilir.
  Future<bool> updateMood(String? moodCategory) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.updateMood(moodCategory);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Dinleyen müsaitlik modu: `available` | `automatic` | `busy`.
  Future<bool> updateListenerAvailability(String availabilityMode) async {
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repo.updateListenerAvailability(availabilityMode);
      state = state.copyWith(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }
}

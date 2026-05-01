import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_user.dart';

part 'auth_state.freezed.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.unknown) AuthStatus status,
    AppUser? user,
    @Default(false) bool onboardingComplete,
    String? errorMessage,
  }) = _AuthState;
}

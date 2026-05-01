import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'route_paths.dart';

/// go_router `refreshListenable` + senkron `redirect` için.
final class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authControllerProvider);
    final loc = state.matchedLocation;

    if (auth.status == AuthStatus.unknown) {
      if (loc == RoutePaths.splash) return null;
      return RoutePaths.splash;
    }

    if (auth.status == AuthStatus.unauthenticated) {
      if (loc == RoutePaths.splash) return RoutePaths.welcome;
      if (loc == RoutePaths.welcome ||
          loc == RoutePaths.login ||
          loc == RoutePaths.register ||
          loc == RoutePaths.forgotPassword ||
          loc == RoutePaths.resetPassword ||
          loc == RoutePaths.verifyEmail) {
        return null;
      }
      return RoutePaths.welcome;
    }

    if (!auth.onboardingComplete && loc != RoutePaths.onboarding) {
      return RoutePaths.onboarding;
    }
    if (auth.onboardingComplete && loc == RoutePaths.onboarding) {
      return RoutePaths.home;
    }

    if (loc == RoutePaths.verifyEmail || loc == RoutePaths.resetPassword) {
      return null;
    }

    const guestRoutes = <String>{
      RoutePaths.splash,
      RoutePaths.welcome,
      RoutePaths.login,
      RoutePaths.register,
      RoutePaths.forgotPassword,
    };
    if (guestRoutes.contains(loc)) return RoutePaths.home;

    return null;
  }
}

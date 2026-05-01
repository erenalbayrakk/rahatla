import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chats/presentation/chats_hub_screen.dart';
import '../../features/group_chat/presentation/group_chat_screen.dart';
import '../../features/group_chat/presentation/group_rooms_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/listener_browse/presentation/listener_browse_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/wallet/presentation/leaderboard_screen.dart';
import '../../features/wallet/presentation/received_session_gifts_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/random_connect/presentation/random_connect_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/support_request/presentation/support_request_screen.dart';
import '../realtime/listener_presence_host.dart';
import 'app_shell.dart';
import 'route_paths.dart';
import 'router_notifier.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(
            initialToken:
                token != null && token.isNotEmpty ? token : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return VerifyEmailScreen(
            initialToken:
                token != null && token.isNotEmpty ? token : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ListenerPresenceHost(
            child: AppShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.randomConnect,
                builder: (context, state) => const RandomConnectScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.chats,
                builder: (context, state) => const ChatsHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.wallet,
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.leaderboard,
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.supportRequest,
        builder: (context, state) => const SupportRequestScreen(),
      ),
      GoRoute(
        path: RoutePaths.browseListeners,
        builder: (context, state) {
          final extra = state.extra;
          final supportRequestId = extra is String ? extra : null;
          return ListenerBrowseScreen(supportRequestId: supportRequestId);
        },
      ),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (context, state) {
          final id = state.pathParameters['sessionId']!;
          return ChatScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.groupRooms,
        builder: (context, state) => const GroupRoomsScreen(),
      ),
      GoRoute(
        path: '/group-chat/:roomId',
        builder: (context, state) {
          final id = state.pathParameters['roomId']!;
          return GroupChatScreen(roomId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.receivedGifts,
        builder: (context, state) => const ReceivedSessionGiftsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

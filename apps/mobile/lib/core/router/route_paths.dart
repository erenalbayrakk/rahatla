abstract final class RoutePaths {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const randomConnect = '/random-connect';
  static const chats = '/chats';
  static const wallet = '/wallet';
  static const receivedGifts = '/received-gifts';
  static const leaderboard = '/leaderboard';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const supportRequest = '/support-request';
  static const browseListeners = '/browse-listeners';

  static String chat(String sessionId) => '/chat/$sessionId';

  static const groupRooms = '/group-rooms';
  static String groupChat(String roomId) => '/group-chat/$roomId';
}

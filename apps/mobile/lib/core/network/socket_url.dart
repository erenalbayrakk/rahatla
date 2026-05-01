/// Socket.IO namespace path (Nest `/realtime`).
String realtimeSocketUrl(String apiBaseUrl) {
  final trimmed = apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
  return '$trimmed/realtime';
}

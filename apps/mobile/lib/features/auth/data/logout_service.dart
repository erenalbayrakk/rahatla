import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_token_storage.dart';

/// Yerel oturumu sonlandırır (JWT silme). Sunucuda ayrı bir logout uç noktası yok.
final logoutServiceProvider = Provider<LogoutService>(
  (ref) => LogoutService(ref.watch(secureTokenStorageProvider)),
);

class LogoutService {
  LogoutService(this._tokens);

  final SecureTokenStorage _tokens;

  Future<void> signOut() async {
    await _tokens.clearAccessToken();
  }
}

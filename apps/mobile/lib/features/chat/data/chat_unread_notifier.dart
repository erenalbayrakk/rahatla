import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_repository.dart';

final chatUnreadNotifierProvider =
    NotifierProvider<ChatUnreadNotifier, int>(ChatUnreadNotifier.new);

/// Okunmamış gelen mesaj sayısı — alt sekmede Sohbet rozeti için periyodik güncellenir.
class ChatUnreadNotifier extends Notifier<int> {
  Timer? _poll;

  @override
  int build() {
    ref.onDispose(() => _poll?.cancel());
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final n =
          await ref.read(chatRepositoryProvider).fetchUnreadIncomingMessagesCount();
      state = n;
    } catch (_) {
      // Önceki sayıyı koru (giriş yokken vb.)
    }
  }
}

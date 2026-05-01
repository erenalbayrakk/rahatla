import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
import '../network/dio_client.dart';
import '../network/socket_url.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// Onaylı dinleyen için uygulama açıkken `/realtime` bağlantısı — API `isOnline` güncellenir
/// (`presenceOverride === auto` iken).
class ListenerPresenceHost extends ConsumerStatefulWidget {
  const ListenerPresenceHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ListenerPresenceHost> createState() =>
      _ListenerPresenceHostState();
}

class _ListenerPresenceHostState extends ConsumerState<ListenerPresenceHost> {
  io.Socket? _socket;
  String? _lastConnectedUserId;
  String? _presenceSyncKey;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final key = auth.status == AuthStatus.authenticated && auth.user != null
        ? '${auth.user!.id}|${auth.user!.role}|${auth.status.name}'
        : auth.status.name;
    if (_presenceSyncKey != key) {
      _presenceSyncKey = key;
      Future.microtask(() => _syncPresenceSocket(auth));
    }
    return widget.child;
  }

  Future<void> _syncPresenceSocket(AuthState auth) async {
    if (auth.status != AuthStatus.authenticated ||
        auth.user?.role != 'approved_listener') {
      _tearDown();
      return;
    }
    final uid = auth.user!.id;
    if (_lastConnectedUserId == uid && _socket?.connected == true) {
      return;
    }
    _tearDown();
    final token = await ref.read(secureTokenStorageProvider).readAccessToken();
    if (token == null || token.isEmpty) return;

    final socket = io.io(
      realtimeSocketUrl(Env.apiBaseUrl),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    _socket = socket;
    _lastConnectedUserId = uid;
  }

  void _tearDown() {
    _socket?.dispose();
    _socket = null;
    _lastConnectedUserId = null;
  }

  @override
  void dispose() {
    _tearDown();
    super.dispose();
  }
}

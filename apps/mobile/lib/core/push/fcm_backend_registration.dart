import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/data/notifications_repository.dart';

/// Oturum açıkken FCM token'ı `POST /notifications/fcm-token` ile API'ye yazar.
class FcmBackendRegistration extends ConsumerStatefulWidget {
  const FcmBackendRegistration({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FcmBackendRegistration> createState() =>
      _FcmBackendRegistrationState();
}

class _FcmBackendRegistrationState extends ConsumerState<FcmBackendRegistration> {
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => _pushToken(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushToken();
    });
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _pushToken() async {
    if (kIsWeb) return;
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      return;
    }
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (!mounted) return;
      if (t == null || t.isEmpty) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await ref.read(notificationsRepositoryProvider).registerFcmToken(
            fcmToken: t,
            platform: platform,
          );
    } catch (_) {
      // Ağ hatası — sessiz; bir sonraki açılış veya token yenilemesinde tekrar
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        _pushToken();
      }
    });
    return widget.child;
  }
}

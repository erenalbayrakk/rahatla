import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/local_cache_provider.dart';
import 'core/storage/local_cache_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await _initFcmForDebug();
  }

  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('parentDataDirty') || msg.contains('semantics')) {
        developer.log(
          'Layout/semantics assertion',
          name: 'rahatla.diag',
          error: details.exception,
          stackTrace: details.stack,
        );
      }
      FlutterError.presentError(details);
    };
  }

  final cache = await LocalCacheService.create();

  runApp(
    ProviderScope(
      overrides: [
        localCacheServiceProvider.overrideWithValue(cache),
      ],
      child: const RahatlaApp(),
    ),
  );
}

/// Geçici: test push / admin formu için FCM token'ı loglar (Xcode / `flutter run` konsolu).
Future<void> _initFcmForDebug() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    final t = await messaging.getToken();
    developer.log('FCM token: $t', name: 'rahatla.fcm');
    messaging.onTokenRefresh.listen((n) {
      developer.log('FCM token (yenilendi): $n', name: 'rahatla.fcm');
    });
  } catch (e, st) {
    developer.log('FCM init hatası: $e', name: 'rahatla.fcm', error: e, stackTrace: st);
  }
}

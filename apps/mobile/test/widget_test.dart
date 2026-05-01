import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rahatla_mobile/app.dart';
import 'package:rahatla_mobile/core/storage/local_cache_provider.dart';
import 'package:rahatla_mobile/core/storage/local_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'read':
            return null;
          case 'write':
          case 'delete':
          case 'deleteAll':
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('RahatlaApp açılır', (WidgetTester tester) async {
    final cache = await LocalCacheService.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localCacheServiceProvider.overrideWithValue(cache),
        ],
        child: const TickerMode(
          enabled: false,
          child: RahatlaApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final splash = find.text('Rahatla').evaluate().isNotEmpty;
    final welcome = find.text('Burada dinlenirsin').evaluate().isNotEmpty;
    expect(splash || welcome, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_cache_provider.dart';

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale>(
  AppLocaleController.new,
);

class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final raw = ref.read(localCacheServiceProvider).languageCode;
    return _fromCode(raw);
  }

  Future<void> setLanguageCode(String code) async {
    final normalized = _normalize(code);
    state = _fromCode(normalized);
    await ref.read(localCacheServiceProvider).setLanguageCode(normalized);
  }

  Locale _fromCode(String raw) => Locale(_normalize(raw));

  String _normalize(String raw) {
    switch (raw.toLowerCase()) {
      case 'en':
        return 'en';
      default:
        return 'tr';
    }
  }
}

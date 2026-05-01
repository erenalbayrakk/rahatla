import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_cache_service.dart';

/// [main] içinde `overrideWithValue` ile bağlanır.
final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => throw StateError('LocalCacheService henüz initialize edilmedi'),
);

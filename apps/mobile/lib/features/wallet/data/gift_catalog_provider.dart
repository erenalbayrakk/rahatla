import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wallet_repository.dart';

/// Sunucudaki hediye fiyatları (oturum açmadan da okunabilir).
final giftCatalogProvider =
    FutureProvider.autoDispose<List<GiftCatalogItemDto>>((ref) async {
  return ref.watch(walletRepositoryProvider).fetchGiftCatalog();
});

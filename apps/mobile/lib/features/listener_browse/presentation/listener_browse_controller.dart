import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../home/state/home_people_filters.dart';
import '../data/listener_browse_repository.dart';
import '../domain/browse_listener.dart';

/// [homeShowAll] ana sayfa: `mood=all` ile tüm onaylı dinleyenler (sayfa başı 30).
/// [profileMoodFilter] liste ekranı: profildeki ruh haline göre API filtresi.
enum ListenerBrowseListMode {
  homeShowAll,
  profileMoodFilter,
}

final listenerBrowseControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ListenerBrowseController, BrowsePage, ListenerBrowseListMode>(
  ListenerBrowseController.new,
);

class ListenerBrowseController
    extends AutoDisposeFamilyAsyncNotifier<BrowsePage, ListenerBrowseListMode> {
  static const _filter = 'all';
  final _random = Random();
  var _loadMoreInFlight = false;

  @override
  Future<BrowsePage> build(ListenerBrowseListMode mode) {
    if (mode == ListenerBrowseListMode.homeShowAll) {
      ref.watch(homePeopleFiltersProvider);
    }
    return _fetch(page: 1, mode: mode);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(page: 1, mode: arg));
  }

  /// Hata mesajı dönerse liste durumu korunur (ilk sayfa `AsyncError` olmaz).
  Future<String?> loadMore() async {
    final current = state.value;
    if (current == null || _loadMoreInFlight || !current.hasMore) return null;
    _loadMoreInFlight = true;
    try {
      final next = await _fetch(page: current.page + 1, mode: arg);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: next.page,
          total: next.total,
          moodFilter: next.moodFilter,
        ),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      _loadMoreInFlight = false;
    }
  }

  Future<String> startSession({
    required String listenerUserId,
    String? supportRequestId,
  }) async {
    final repo = ref.read(listenerBrowseRepositoryProvider);
    try {
      final session = await repo.createSessionFromSelection(
        listenerUserId: listenerUserId,
        supportRequestId: supportRequestId,
      );
      return session.id;
    } on ApiException {
      rethrow;
    }
  }

  Future<String> startRandomSession({String? supportRequestId}) async {
    final repo = ref.read(listenerBrowseRepositoryProvider);
    try {
      final session = await repo.createSessionFromRandom(
        supportRequestId: supportRequestId,
      );
      return session.id;
    } on ApiException {
      rethrow;
    }
  }

  Future<BrowsePage> _fetch({
    required int page,
    required ListenerBrowseListMode mode,
  }) async {
    final repo = ref.read(listenerBrowseRepositoryProvider);
    final hf = mode == ListenerBrowseListMode.homeShowAll
        ? ref.read(homePeopleFiltersProvider)
        : null;
    final mood = mode == ListenerBrowseListMode.homeShowAll
        ? (hf!.moodCategoryKey == null || hf.moodCategoryKey!.isEmpty
            ? 'all'
            : hf.moodCategoryKey!)
        : null;
    final data = await repo.fetchBrowse(
      filter: _filter,
      page: page,
      mood: mood,
      q: hf != null && hf.query.trim().isNotEmpty ? hf.query.trim() : null,
      minAge: hf != null && hf.applyAgeFilter ? hf.minAge : null,
      maxAge: hf != null && hf.applyAgeFilter ? hf.maxAge : null,
      gender: hf != null && (hf.genderKey?.isNotEmpty ?? false)
          ? hf.genderKey
          : null,
    );
    if (page == 1) {
      return _shuffleFirstPage(data);
    }
    return data;
  }

  BrowsePage _shuffleFirstPage(BrowsePage p) {
    if (p.items.length <= 1) return p;
    final pinned = p.items.where((e) => e.pinned).toList();
    final rest = p.items.where((e) => !e.pinned).toList();
    rest.shuffle(_random);
    return p.copyWith(items: [...pinned, ...rest]);
  }
}

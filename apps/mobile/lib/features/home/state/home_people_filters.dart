import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana sayfa «Kişiler» — isim araması ve API filtreleri.
class HomePeopleFilters {
  const HomePeopleFilters({
    this.query = '',
    this.moodCategoryKey,
    this.genderKey,
    this.applyAgeFilter = false,
    this.minAge = 22,
    this.maxAge = 55,
  });

  final String query;

  /// `SupportCategory` veya null = tümü.
  final String? moodCategoryKey;

  /// API: female, male, non_binary, prefer_not_to_say
  final String? genderKey;

  final bool applyAgeFilter;
  final int minAge;
  final int maxAge;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      (moodCategoryKey != null && moodCategoryKey!.isNotEmpty) ||
      (genderKey != null && genderKey!.isNotEmpty) ||
      applyAgeFilter;
}

class HomePeopleFiltersNotifier extends StateNotifier<HomePeopleFilters> {
  HomePeopleFiltersNotifier() : super(const HomePeopleFilters());

  void setQuery(String q) {
    state = HomePeopleFilters(
      query: q,
      moodCategoryKey: state.moodCategoryKey,
      genderKey: state.genderKey,
      applyAgeFilter: state.applyAgeFilter,
      minAge: state.minAge,
      maxAge: state.maxAge,
    );
  }

  void setMood(String? moodCategoryKey) {
    state = HomePeopleFilters(
      query: state.query,
      moodCategoryKey: moodCategoryKey,
      genderKey: state.genderKey,
      applyAgeFilter: state.applyAgeFilter,
      minAge: state.minAge,
      maxAge: state.maxAge,
    );
  }

  void setGender(String? genderKey) {
    state = HomePeopleFilters(
      query: state.query,
      moodCategoryKey: state.moodCategoryKey,
      genderKey: genderKey,
      applyAgeFilter: state.applyAgeFilter,
      minAge: state.minAge,
      maxAge: state.maxAge,
    );
  }

  void setAgeFilter({
    required bool apply,
    required int minAge,
    required int maxAge,
  }) {
    state = HomePeopleFilters(
      query: state.query,
      moodCategoryKey: state.moodCategoryKey,
      genderKey: state.genderKey,
      applyAgeFilter: apply,
      minAge: minAge,
      maxAge: maxAge,
    );
  }

  void clearAll() => state = const HomePeopleFilters();
}

final homePeopleFiltersProvider =
    StateNotifierProvider<HomePeopleFiltersNotifier, HomePeopleFilters>(
  (ref) => HomePeopleFiltersNotifier(),
);

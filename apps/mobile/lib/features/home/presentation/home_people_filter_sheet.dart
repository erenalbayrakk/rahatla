import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_text.dart';
import '../state/home_people_filters.dart';

/// Keşif: yaş + cinsiyet sheet içinde seçilir; değişiklikler [Uygula] ile provider’a yazılır ve liste yenilenir.
Future<void> showHomePeopleFilterSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) => const _KesifDemographicsSheet(),
  );
}

class _KesifDemographicsSheet extends ConsumerStatefulWidget {
  const _KesifDemographicsSheet();

  @override
  ConsumerState<_KesifDemographicsSheet> createState() =>
      _KesifDemographicsSheetState();
}

class _KesifDemographicsSheetState extends ConsumerState<_KesifDemographicsSheet> {
  String? _gender;
  late int _minAge;
  late int _maxAge;

  @override
  void initState() {
    super.initState();
    final c = ref.read(homePeopleFiltersProvider);
    _gender = c.genderKey;
    _minAge = c.minAge.clamp(18, 78);
    _maxAge = c.maxAge.clamp(19, 80);
    if (_minAge >= _maxAge) {
      _maxAge = _minAge + 1;
    }
  }

  void _setLocalGender(String? g) {
    setState(() => _gender = g);
  }

  void _setLocalAge({int? minAge, int? maxAge}) {
    final mn = minAge ?? _minAge;
    final mx = maxAge ?? _maxAge;
    setState(() {
      _minAge = mn.clamp(18, 78);
      _maxAge = mx.clamp(19, 80);
      if (_minAge >= _maxAge) {
        _maxAge = _minAge + 1;
      }
    });
  }

  /// Sheet seçimlerini kalıcı yapıp listeyi günceller (`listenerBrowseController` watch ile yenilenir).
  void _commitAndClose() {
    ref.read(homePeopleFiltersProvider.notifier)
      ..setGender(_gender)
      ..setAgeFilter(
        apply: true,
        minAge: _minAge,
        maxAge: _maxAge,
      );
    Navigator.of(context).pop();
  }

  Widget _pill(
    ThemeData theme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  static const double _ageSliderMin = 18;
  static const double _ageSliderMax = 80;

  void _onAgeRangeChanged(RangeValues v) {
    var lo = v.start.round().clamp(18, 78);
    var hi = v.end.round().clamp(19, 80);
    if (hi <= lo) hi = lo + 1;
    _setLocalAge(minAge: lo, maxAge: hi);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trEn(context, 'Keşif', 'Discover'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                trEn(context, 'Yaş ve cinsiyet', 'Age and gender'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trEn(context, 'Cinsiyet', 'Gender'),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    theme,
                    label: trEn(context, 'Tümü', 'All'),
                    selected: _gender == null,
                    onTap: () => _setLocalGender(null),
                  ),
                  _pill(
                    theme,
                    label: trEn(context, 'Kadın', 'Woman'),
                    selected: _gender == 'female',
                    onTap: () => _setLocalGender('female'),
                  ),
                  _pill(
                    theme,
                    label: trEn(context, 'Erkek', 'Man'),
                    selected: _gender == 'male',
                    onTap: () => _setLocalGender('male'),
                  ),
                  _pill(
                    theme,
                    label: 'Non-binary',
                    selected: _gender == 'non_binary',
                    onTap: () => _setLocalGender('non_binary'),
                  ),
                  _pill(
                    theme,
                    label: trEn(context, 'Belirtmek istemiyorum', 'Prefer not to say'),
                    selected: _gender == 'prefer_not_to_say',
                    onTap: () => _setLocalGender('prefer_not_to_say'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trEn(context, 'Yaş aralığı', 'Age range'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: RangeSlider(
                  values: RangeValues(
                    _minAge.toDouble(),
                    _maxAge.toDouble(),
                  ),
                  min: _ageSliderMin,
                  max: _ageSliderMax,
                  divisions: (_ageSliderMax - _ageSliderMin).round(),
                  labels: RangeLabels(
                    '$_minAge',
                    '$_maxAge',
                  ),
                  onChanged: _onAgeRangeChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trEn(context, 'Başlangıç', 'From'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_minAge yaş',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trEn(context, 'Bitiş', 'To'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEnglishLocale(context) ? 'Age $_maxAge' : '$_maxAge yaş',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _commitAndClose,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(trEn(context, 'Uygula', 'Apply')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../locale/locale_text.dart';

/// API `SupportCategory` ile aynı anahtarlar (profil ruh hali).
class MoodCatalog {
  MoodCatalog._();

  static const Map<String, String> _labelEn = {
    'feeling_neutral': 'Neutral',
    'vent': 'I need to vent',
    'need_someone_to_listen': 'I need someone to listen',
    'calm_chat': 'I want a calm chat',
    'motivation': 'I need motivation',
    'not_feeling_alone': "I don't want to feel alone",
    'available': 'Available',
    'automatic': 'Automatic',
    'busy': 'Busy',
  };

  /// Profil «dinleyen durumu» (API) — ayrı ruh hali listesinde yok.
  static const Map<String, String> _listenerAvailTr = {
    'available': 'Müsait',
    'automatic': 'Otomatik',
    'busy': 'Yoğun',
  };

  static const List<MoodOption> options = [
    MoodOption(
      apiValue: 'feeling_neutral',
      label: 'Orta — nötr',
      icon: Icons.sentiment_neutral_outlined,
    ),
    MoodOption(
      apiValue: 'vent',
      label: 'İçimi dökmek istiyorum',
      icon: Icons.water_drop_outlined,
    ),
    MoodOption(
      apiValue: 'need_someone_to_listen',
      label: 'Sadece biri beni dinlesin',
      icon: Icons.hearing_outlined,
    ),
    MoodOption(
      apiValue: 'calm_chat',
      label: 'Sakin sohbet istiyorum',
      icon: Icons.local_cafe_outlined,
    ),
    MoodOption(
      apiValue: 'motivation',
      label: 'Motivasyona ihtiyacım var',
      icon: Icons.trending_up_rounded,
    ),
    MoodOption(
      apiValue: 'not_feeling_alone',
      label: 'Yalnız hissetmek istemiyorum',
      icon: Icons.favorite_outline_rounded,
    ),
  ];

  static String? labelFor(String? apiValue) {
    if (apiValue == null || apiValue.isEmpty) return null;
    for (final o in options) {
      if (o.apiValue == apiValue) return o.label;
    }
    return _listenerAvailTr[apiValue];
  }

  /// Profil / liste için TR veya EN etiket.
  static String labelLocalized(BuildContext context, String apiValue) {
    final tr = labelFor(apiValue) ?? apiValue;
    final en = _labelEn[apiValue] ?? tr;
    return trEn(context, tr, en);
  }

  static IconData? iconFor(String? apiValue) {
    if (apiValue == null || apiValue.isEmpty) return null;
    for (final o in options) {
      if (o.apiValue == apiValue) return o.icon;
    }
    return null;
  }
}

class MoodOption {
  const MoodOption({
    required this.apiValue,
    required this.label,
    required this.icon,
  });

  final String apiValue;
  final String label;
  final IconData icon;
}

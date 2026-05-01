import 'package:flutter/widgets.dart';

import '../../../core/locale/locale_text.dart';

/// API `browse.replyPace` ile uyumlu kısa etiketler (son yanıtlara göre ortalama).
String? browseReplyPaceChipLabel(BuildContext context, String? pace) {
  return switch (pace) {
    'spark' => trEn(
        context,
        'Yanıt mükemmel',
        'Replies instantly',
      ),
    'swift' => trEn(
        context,
        'Yanıt tatlı',
        'Quick replies',
      ),
    'warm' => trEn(
        context,
        'Yanıt rahat tempo',
        'Relaxed pace',
      ),
    'easy' => trEn(
        context,
        'Yanıt ara sıra',
        'Slower replies',
      ),
    _ => null,
  };
}

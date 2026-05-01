import 'package:flutter/widgets.dart';

bool isEnglishLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';

String trEn(BuildContext context, String tr, String en) =>
    isEnglishLocale(context) ? en : tr;

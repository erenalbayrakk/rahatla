import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  LocalCacheService(this._prefs);

  static const _onboardingKey = 'onboarding_complete';
  static const _selfieSkipKey = 'selfie_step_skipped';
  static const _selfieDoneKey = 'selfie_step_completed';
  static const _themeModeKey = 'theme_mode';
  static const _languageCodeKey = 'language_code';

  final SharedPreferences _prefs;

  static Future<LocalCacheService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalCacheService(prefs);
  }

  bool get onboardingComplete => _prefs.getBool(_onboardingKey) ?? false;
  bool get selfieStepSkipped => _prefs.getBool(_selfieSkipKey) ?? false;
  bool get selfieStepCompleted => _prefs.getBool(_selfieDoneKey) ?? false;
  String get themeMode => _prefs.getString(_themeModeKey) ?? 'system';
  String get languageCode => _prefs.getString(_languageCodeKey) ?? 'tr';

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_onboardingKey, value);

  Future<void> setSelfieStepSkipped(bool value) =>
      _prefs.setBool(_selfieSkipKey, value);

  Future<void> setSelfieStepCompleted(bool value) =>
      _prefs.setBool(_selfieDoneKey, value);

  Future<void> setThemeMode(String value) => _prefs.setString(_themeModeKey, value);
  Future<void> setLanguageCode(String value) =>
      _prefs.setString(_languageCodeKey, value);
}

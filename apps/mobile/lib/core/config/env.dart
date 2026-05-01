/// API tabanı. Android emülatör: `http://10.0.2.2:3000`
/// iOS simülatör: `http://localhost:3000`
/// Fiziksel cihaz: makinenin LAN IP’si.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}

class Env {
  /// URL de l'API ExLibris
  /// 
  /// Pour dev local: http://127.0.0.1:8000
  /// Pour production: http://87.106.141.247/exlibris-api
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000', // API locale
  );
}



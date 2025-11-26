class Env {
  /// Passe l'URL de l'API au run:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // émulateur Android -> PC
  );
}

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static String _suffix = '';

  /// Définit un suffixe pour les clés de stockage (utile pour l'isolation de session)
  static void setSessionSuffix(String suffix) {
    _suffix = suffix;
  }

  static String get _key => 'auth_token$_suffix';

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

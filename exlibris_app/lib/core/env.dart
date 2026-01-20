import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// URL de l'API ExLibris
  /// 
  /// Pour dev local: http://127.0.0.1:8000
  /// Pour production: http://87.106.141.247/exlibris-api
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.13:8000';
}



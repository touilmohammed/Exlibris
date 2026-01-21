import 'package:dio/dio.dart';
import 'env.dart';
import 'token_storage.dart';

Dio buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Ajoute automatiquement le JWT s'il existe
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.read();
        print('DIO DEBUG: Requesting ${options.path}');
        if (token != null) {
          print('DIO DEBUG: Attaching token ${token.substring(0, 5)}...');
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          print('DIO DEBUG: No token found in storage');
        }
        handler.next(options);
      },
      onError: (e, handler) {
        // Si 401 -> on efface le token (session expirée)
        if (e.response?.statusCode == 401) {
          TokenStorage.clear();
        }
        handler.next(e);
      },
    ),
  );

  return dio;
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';

final dioProvider = Provider<Dio>((ref) => buildDio());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepository(dio);
});

class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  /// Inscription
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    await _dio.post(
      '/auth/signup',
      data: {
        'email': email,
        'nom_utilisateur': username,
        'mot_de_passe': password,
      },
    );
  }

  /// Confirmation par token (optionnel si votre back le fait)
  Future<void> confirmEmail({required String token}) async {
    await _dio.post('/auth/confirm', data: {'token': token});
  }

  /// Connexion -> enregistre le JWT
  Future<void> signIn({required String email, required String password}) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'mot_de_passe': password},
    );
    final token = (res.data is Map && (res.data as Map)['token'] != null)
        ? (res.data as Map)['token'] as String
        : throw Exception('Réponse login invalide (token manquant)');
    await TokenStorage.save(token);
  }

  Future<void> signOut() async => TokenStorage.clear();
}

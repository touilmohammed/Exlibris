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

  /// Confirmation par code
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    await _dio.post(
      '/auth/confirm',
      data: {'email': email, 'code': code},
    );
  }

  /// Renvoyer le code de confirmation
  Future<void> resendConfirmation({required String email}) async {
    await _dio.post(
      '/auth/resend-confirmation',
      data: {'email': email},
    );
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

  Future<void> publishPgpKeys({
    required String publicKey,
    required String privateKeyEnc,
  }) async {
    await _dio.post(
      '/auth/pgp',
      data: {
        'public_key': publicKey,
        'private_key_enc': privateKeyEnc,
      },
    );
  }
}

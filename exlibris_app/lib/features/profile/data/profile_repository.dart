import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart'; // pour dioProvider
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.read(dioProvider);
  return ProfileRepository(dio);
});

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<UserProfile> getMyProfile() async {
    final response = await _dio.get('/me/profile');
    return UserProfile.fromJson(response.data);
  }

  Future<void> updateProfile({
    String? nomUtilisateur,
    String? email,
    String? motDePasse,
    int? age,
    String? sexe,
    String? pays,
  }) async {
    final data = {
      if (nomUtilisateur != null) 'nom_utilisateur': nomUtilisateur,
      if (email != null) 'email': email,
      if (motDePasse != null) 'mot_de_passe': motDePasse,
      if (age != null) 'age': age,
      if (sexe != null) 'sexe': sexe,
      if (pays != null) 'pays': pays,
    };

    if (data.isEmpty) return;

    await _dio.patch('/me/profile', data: data);
  }
}

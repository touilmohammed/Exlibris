import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/rating.dart';
import '../../auth/data/auth_repository.dart';

/// Provider du repository des évaluations
final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  final dio = ref.read(dioProvider); // même Dio que pour auth / livres
  return RatingsRepository(dio);
});

class RatingsRepository {
  final Dio _dio;
  RatingsRepository(this._dio);

  /// Récupérer toutes les évaluations de l'utilisateur courant
  /// (ton endpoint GET /me/ratings côté FastAPI)
  Future<List<Rating>> getMyRatings({String? isbn}) async {
    final res = await _dio.get(
      '/me/ratings',
      queryParameters: isbn != null ? {'isbn': isbn} : null,
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Rating.fromJson)
          .toList();
    }

    throw Exception('Format /me/ratings invalide : $data');
  }

  /// Ajouter ou mettre à jour une note/avis
  /// (POST /me/ratings côté FastAPI)
  Future<void> addOrUpdateRating({
    required String isbn,
    required int note,
    String? avis,
  }) async {
    await _dio.post(
      '/me/ratings',
      data: {
        'isbn': isbn,
        'note': note,
        if (avis != null && avis.isNotEmpty) 'avis': avis,
      },
    );
  }

  // ---- Méthodes utilitaires pour coller à add_rating_sheet.dart ----

  /// Récupérer la note pour UN seul livre
  Future<Rating?> getMyRatingFor(String isbn) async {
    final list = await getMyRatings(isbn: isbn);
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Alias plus lisible pour sauvegarder
  Future<void> saveRating({
    required String isbn,
    required int note,
    String? avis,
  }) async {
    await addOrUpdateRating(isbn: isbn, note: note, avis: avis);
  }
}

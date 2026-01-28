import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../../auth/data/auth_repository.dart'; // pour dioProvider

/// On réutilise le même dioProvider que pour l’auth
final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  final dio = ref.read(
    dioProvider,
  ); // dioProvider vient de auth_repository.dart
  return BooksRepository(dio);
});

class BooksRepository {
  final Dio _dio;
  BooksRepository(this._dio);

  /// Recherche de livres
  Future<List<Book>> searchBooks({
    String? query,
    String? auteur,
    String? isbn,
  }) async {
    final queryParams = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) {
      queryParams['query'] = query.trim();
    }
    if (auteur != null && auteur.trim().isNotEmpty) {
      queryParams['auteur'] = auteur.trim();
    }
    if (isbn != null && isbn.trim().isNotEmpty) {
      queryParams['isbn'] = isbn.trim();
    }

    final res = await _dio.get(
      '/livres',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    if (res.data is List) {
      final data = res.data as List;
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => Book.fromJson(m))
          .toList();
    }

    if (res.data is Map && (res.data as Map)['items'] is List) {
      final data = (res.data as Map)['items'] as List;
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => Book.fromJson(m))
          .toList();
    }

    throw Exception('Format de réponse /livres invalide : ${res.data}');
  }

  /// Récupérer la collection de l’utilisateur
  Future<List<Book>> getCollection() async {
    final res = await _dio.get('/me/collection');
    if (res.data is List) {
      final data = res.data as List;
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => Book.fromJson(m))
          .toList();
    }
    throw Exception('Format de réponse /me/collection invalide : ${res.data}');
  }

  /// Récupérer les recommandations de livres pour l’utilisateur
  Future<List<Book>> getRecommendations() async {
    final res = await _dio.get('/me/recommendations');
    if (res.data is List) {
      final data = res.data as List;
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => Book.fromJson(m))
          .toList();
    }
    throw Exception(
        'Format de réponse /me/recommendations invalide : ${res.data}');
  }

  /// Ajouter un livre à la collection
  Future<void> addToCollection(String isbn) async {
    await _dio.post('/me/collection', data: {'isbn': isbn});
  }

  /// Supprimer un livre de la collection
  Future<void> removeFromCollection(String isbn) async {
    await _dio.delete('/me/collection', queryParameters: {'isbn': isbn});
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../../auth/data/auth_repository.dart'; // pour dioProvider

/// Provider du repository wishlist
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  final dio = ref.read(dioProvider);
  return WishlistRepository(dio);
});

class WishlistRepository {
  final Dio _dio;
  WishlistRepository(this._dio);

  /// Récupère la wishlist depuis l'API
  Future<List<Book>> getWishlist() async {
    final res = await _dio.get('/me/wishlist');

    if (res.data is List) {
      final data = res.data as List;
      return data.whereType<Map<String, dynamic>>().map(Book.fromJson).toList();
    }

    throw Exception('Format de réponse /me/wishlist invalide : ${res.data}');
  }

  /// Ajoute un livre à la wishlist
  Future<void> add(String isbn) async {
    await _dio.post('/me/wishlist', data: {'isbn': isbn});
  }

  /// Retire un livre de la wishlist
  Future<void> remove(String isbn) async {
    await _dio.delete('/me/wishlist', queryParameters: {'isbn': isbn});
  }
}

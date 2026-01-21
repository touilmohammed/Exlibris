import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exchange.dart';
import '../../../models/book.dart';
import '../../auth/data/auth_repository.dart'; // pour dioProvider

final exchangesRepositoryProvider = Provider<ExchangesRepository>((ref) {
  final dio = ref.read(dioProvider);
  return ExchangesRepository(dio);
});

class ExchangesRepository {
  final Dio _dio;

  ExchangesRepository(this._dio);

  /// Créer un nouvel échange
  Future<Exchange> createExchange({
    required int destinataireId,
    required String livreDemandeurIsbn,
    required String livreDestinataireIsbn,
  }) async {
    final res = await _dio.post(
      '/exchanges',
      data: {
        'destinataire_id': destinataireId,
        'livre_demandeur_isbn': livreDemandeurIsbn,
        'livre_destinataire_isbn': livreDestinataireIsbn,
      },
    );

    return Exchange.fromJson(res.data as Map<String, dynamic>);
  }

  /// Récupérer tous mes échanges (envoyés + reçus)
  Future<List<Exchange>> getMyExchanges() async {
    final res = await _dio.get('/me/exchanges');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Exchange.fromJson)
          .toList();
    }
    throw Exception('Format /me/exchanges invalide: $data');
  }

  /// Récupérer la collection d'un ami
  Future<List<Book>> getFriendCollection(int friendId) async {
    final res = await _dio.get('/users/$friendId/collection');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Book.fromJson)
          .toList();
    }
    throw Exception('Format /users/$friendId/collection invalide: $data');
  }

  /// Accepter un échange (en tant que destinataire)
  Future<void> acceptExchange(int id) async {
    await _dio.post('/exchanges/$id/accept');
  }

  /// Refuser un échange
  Future<void> refuseExchange(int id) async {
    await _dio.post('/exchanges/$id/refuse');
  }

  /// Annuler un échange (en tant que demandeur)
  Future<void> cancelExchange(int id) async {
    await _dio.post('/exchanges/$id/cancel');
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../auth/data/auth_repository.dart'; // pour dioProvider

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final dio = ref.read(dioProvider);
  return FriendsRepository(dio);
});

class FriendsRepository {
  final Dio _dio;
  FriendsRepository(this._dio);

  /// Amis actuels
  Future<List<Friend>> getFriends() async {
    final res = await _dio.get('/friends');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Friend.fromJson)
          .toList();
    }
    throw Exception('Format /friends invalide: $data');
  }

  /// Demandes reçues
  Future<List<Friend>> getIncomingRequests() async {
    final res = await _dio.get('/friends/requests');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Friend.fromJson)
          .toList();
    }
    throw Exception('Format /friends/requests invalide: $data');
  }

  /// Demandes envoyées (en attente)
  Future<List<Friend>> getOutgoingRequests() async {
    final res = await _dio.get('/friends/requests-outgoing');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Friend.fromJson)
          .toList();
    }
    throw Exception('Format /friends/requests-outgoing invalide: $data');
  }

  /// Accepter une demande reçue
  Future<void> acceptRequest(int friendId) async {
    await _dio.post('/friends/requests/$friendId/accept');
  }

  /// Refuser une demande reçue
  Future<void> refuseRequest(int friendId) async {
    await _dio.post('/friends/requests/$friendId/refuse');
  }

  /// Supprimer un ami
  Future<void> removeFriend(int friendId) async {
    await _dio.delete('/friends/$friendId');
  }

  /// Recherche de nouveaux amis
  Future<List<Friend>> search(String q) async {
    final res = await _dio.get('/friends/search', queryParameters: {'q': q});

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>() // sécurise le typage
          .map(Friend.fromJson)
          .toList();
    }

    throw Exception('Format /friends/search invalide: $data');
  }

  /// Envoyer une nouvelle demande (qui ira dans "demandes envoyées" côté backend)
  Future<void> sendRequest(int friendId) async {
    await _dio.post('/friends/requests/$friendId');
  }
}

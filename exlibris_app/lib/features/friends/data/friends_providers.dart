import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import 'friends_repository.dart';

/// Liste de mes amis
final friendsListProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final repo = ref.read(friendsRepositoryProvider);
  return repo.getFriends();
});

/// Liste des demandes d’amis reçues
final incomingFriendRequestsProvider = FutureProvider.autoDispose<List<Friend>>((
  ref,
) async {
  final repo = ref.read(friendsRepositoryProvider);
  return repo.getIncomingRequests();
});

/// Liste des demandes d’amis envoyées (en attente)
final outgoingFriendRequestsProvider = FutureProvider.autoDispose<List<Friend>>((
  ref,
) async {
  final repo = ref.read(friendsRepositoryProvider);
  return repo.getOutgoingRequests();
});

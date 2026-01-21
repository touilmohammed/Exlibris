import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exchange.dart';
import '../../../models/book.dart';
import 'exchanges_repository.dart';

/// Tous les échanges où je suis impliqué (demandeur ou destinataire)
final myExchangesProvider = FutureProvider.autoDispose<List<Exchange>>((ref) async {
  final repo = ref.read(exchangesRepositoryProvider);
  return repo.getMyExchanges();
});

/// Collection d'un ami (pour faire son choix)
final friendCollectionProvider = FutureProvider.family<List<Book>, int>((ref, friendId) async {
  final repo = ref.read(exchangesRepositoryProvider);
  return repo.getFriendCollection(friendId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exchange.dart';
import 'exchanges_repository.dart';

/// Tous les échanges où je suis impliqué (demandeur ou destinataire)
final myExchangesProvider = FutureProvider<List<Exchange>>((ref) async {
  final repo = ref.read(exchangesRepositoryProvider);
  return repo.getMyExchanges();
});

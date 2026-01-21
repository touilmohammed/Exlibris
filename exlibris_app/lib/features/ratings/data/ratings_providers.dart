import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/rating.dart';
import 'ratings_repository.dart';

/// Toutes les notes de l'utilisateur courant
final myRatingsProvider = FutureProvider.autoDispose<List<Rating>>((ref) async {
  final repo = ref.read(ratingsRepositoryProvider);
  return repo.getMyRatings();
});

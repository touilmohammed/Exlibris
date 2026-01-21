import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../data/books_repository.dart';
import '../../wishlist/data/wishlist_repository.dart';

/// ----------------------------------------------------------------------
/// COLLECTION (synchronisée API)
/// ----------------------------------------------------------------------

final collectionProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final repo = ref.read(booksRepositoryProvider);
  return repo.getCollection();
});

/// ----------------------------------------------------------------------
/// WISHLIST
/// ----------------------------------------------------------------------

class WishlistNotifier extends StateNotifier<List<Book>> {
  final WishlistRepository _repo;

  WishlistNotifier(this._repo) : super([]) {
    _loadInitial();
  }

  /// Chargement initial depuis l’API
  Future<void> _loadInitial() async {
    try {
      final books = await _repo.getWishlist();
      state = books;
    } catch (e) {
      // Erreur silencieuse ou log
    }
  }

  bool contains(Book book) => state.any((b) => b.isbn == book.isbn);

  Future<void> add(Book book) async {
    if (contains(book)) return;

    await _repo.add(book.isbn);
    state = [...state, book];
  }

  Future<void> remove(Book book) async {
    if (!contains(book)) return;

    await _repo.remove(book.isbn);
    state = state.where((b) => b.isbn != book.isbn).toList();
  }
}

/// Provider global
final wishlistProvider = StateNotifierProvider.autoDispose<WishlistNotifier, List<Book>>((
  ref,
) {
  final repo = ref.read(wishlistRepositoryProvider);
  return WishlistNotifier(repo);
});

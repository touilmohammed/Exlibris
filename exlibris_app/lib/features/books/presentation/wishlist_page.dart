import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books_providers.dart';
import '../../../models/book.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes souhaits')),
      body: wishlist.isEmpty
          ? const Center(
              child: Text(
                'Ta liste de souhaits est vide.\nAjoute des livres depuis l’onglet Explorer.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: wishlist.length,
              itemBuilder: (context, index) {
                final book = wishlist[index];
                return _WishlistTile(book: book);
              },
            ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  final Book book;
  const _WishlistTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            book.titre.isNotEmpty ? book.titre[0].toUpperCase() : '?',
          ),
        ),
        title: Text(book.titre),
        subtitle: Text(
          '${book.auteur}${book.categorie != null ? ' · ${book.categorie}' : ''}',
        ),
        trailing: IconButton(
          tooltip: 'Retirer de la wishlist',
          icon: const Icon(Icons.favorite),
          color: Colors.red,
          onPressed: () {
            final notifier = ref.read(wishlistProvider.notifier);
            notifier.remove(book);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Retiré de la wishlist : ${book.titre}')),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/books_providers.dart';
import '../../../models/book.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);

    if (wishlist.isEmpty) {
      return const Center(
        child: Text(
          'Tu n’as encore aucun livre dans ta liste de souhaits.\n'
          'Ajoute-en depuis l’onglet Explorer ❤️',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wishlist.length,
      itemBuilder: (context, index) {
        final book = wishlist[index];
        return _WishlistItem(book: book);
      },
    );
  }
}

class _WishlistItem extends ConsumerWidget {
  final Book book;
  const _WishlistItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(wishlistProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            book.titre.isNotEmpty ? book.titre[0].toUpperCase() : '?',
          ),
        ),
        title: Text(book.titre),
        subtitle: Text(book.auteur),
        trailing: IconButton(
          tooltip: 'Retirer de la wishlist',
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () {
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

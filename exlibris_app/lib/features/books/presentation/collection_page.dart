import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/books_providers.dart';
import '../../books/data/books_repository.dart';
import '../../../models/book.dart';

class CollectionPage extends ConsumerWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCollection = ref.watch(collectionProvider);

    return asyncCollection.when(
      data: (books) => _CollectionList(books: books),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (err, stack) =>
          Center(child: Text('Erreur chargement collection : $err')),
    );
  }
}

class _CollectionList extends ConsumerWidget {
  final List<Book> books;
  const _CollectionList({required this.books});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (books.isEmpty) {
      return const Center(
        child: Text(
          'Ta collection est vide pour l’instant.\nAjoute des livres depuis l’onglet Explorer.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final repo = ref.read(booksRepositoryProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
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
              tooltip: 'Retirer de ma collection',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await repo.removeFromCollection(book.isbn);
                ref.invalidate(collectionProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Retiré de la collection : ${book.titre}'),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}

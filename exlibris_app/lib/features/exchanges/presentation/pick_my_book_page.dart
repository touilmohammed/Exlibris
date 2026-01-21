import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../models/book.dart';
import '../../../models/friend.dart';
import '../../books/data/books_providers.dart';

class PickMyBookPage extends ConsumerWidget {
  final Friend friend;

  const PickMyBookPage({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Je donne...'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: collectionAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Text(
                'Aucun livre dans ta collection à échanger.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final hasImage =
                  book.imagePetite != null && book.imagePetite!.isNotEmpty;

              return InkWell(
                onTap: () {
                  context.push(
                    '/exchange/pick-theirs',
                    extra: {
                      'friend': friend,
                      'myBook': book,
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.cardBackground,
                          image: hasImage
                              ? DecorationImage(
                                  image: NetworkImage(book.imagePetite!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasImage
                            ? const Center(
                                child: Icon(Icons.book,
                                    color: Colors.white24, size: 32),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erreur: $err',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../books/data/books_providers.dart';
import '../../books/data/books_repository.dart';
import '../../../models/book.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';

class CollectionPage extends ConsumerWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCollection = ref.watch(collectionProvider);

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: asyncCollection.when(
          data: (books) => _CollectionList(books: books),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.success),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Erreur chargement collection : $err',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionList extends ConsumerWidget {
  final List<Book> books;
  const _CollectionList({required this.books});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ta collection est vide pour l\'instant.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute des livres depuis l\'onglet Explorer.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final repo = ref.read(booksRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('Ma collection', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            '${books.length} livre${books.length > 1 ? 's' : ''}',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Grid of books
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookGridItem(
                  book: book,
                  onRemove: () async {
                    await repo.removeFromCollection(book.isbn);
                    ref.invalidate(collectionProvider);
                    if (context.mounted) {
                      AppToast.success(context, 'Retiré de la collection : ${book.titre}');
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final Book book;
  final VoidCallback onRemove;

  const _BookGridItem({
    required this.book,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book', extra: book),
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.gradientEnd,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.titre, style: AppTextStyles.heading3),
                Text(book.auteur, style: AppTextStyles.body),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text(
                    'Retirer de ma collection',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRemove();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Container(
            decoration: BoxDecoration(
              color: AppColors.gradientEnd,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: book.imagePetite != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: book.imagePetite!,
                      httpHeaders: {
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                      },
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(
                            Icons.menu_book,
                            size: 32,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(
                        Icons.menu_book,
                        size: 32,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            book.titre,
            style: AppTextStyles.bodyWhite,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Author
          Text(
            book.auteur,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

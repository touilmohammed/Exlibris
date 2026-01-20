import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/books_providers.dart';
import '../../../models/book.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: wishlist.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ta liste de souhaits est vide.',
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
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text('Mes souhaits', style: AppTextStyles.heading2),
                    const SizedBox(height: 4),
                    Text(
                      '${wishlist.length} livre${wishlist.length > 1 ? 's' : ''} dans ta wishlist',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 20),

                    // List of books
                    Expanded(
                      child: ListView.builder(
                        itemCount: wishlist.length,
                        itemBuilder: (context, index) {
                          final book = wishlist[index];
                          return _WishlistTile(book: book);
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  final Book book;
  const _WishlistTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppDecorations.cardDecoration,
      child: ListTile(
        onTap: () => context.push('/book', extra: book),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.gradientEnd,
            borderRadius: BorderRadius.circular(8),
            image: book.imagePetite != null
                ? DecorationImage(
                    image: NetworkImage(book.imagePetite!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: book.imagePetite == null
              ? Center(
                  child: Text(
                    book.titre.isNotEmpty ? book.titre[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        title: Text(
          book.titre,
          style: AppTextStyles.bodyWhite,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${book.auteur}${book.categorie != null ? ' · ${book.categorie}' : ''}',
          style: AppTextStyles.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Retirer de la wishlist',
          icon: const Icon(Icons.favorite, color: AppColors.error),
          onPressed: () {
            final notifier = ref.read(wishlistProvider.notifier);
            notifier.remove(book);
            AppToast.success(context, 'Retiré de la wishlist : ${book.titre}');
          },
        ),
      ),
    );
  }
}

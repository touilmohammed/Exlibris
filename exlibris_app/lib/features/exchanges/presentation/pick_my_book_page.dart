import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Proposer un echange'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: collectionAsync.when(
            data: (books) {
              if (books.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: AppEmptyStateCard(
                      icon: Icons.library_books_outlined,
                      title: 'Aucun livre a proposer.',
                      subtitle:
                          'Ajoute des livres dans ta bibliotheque avant de lancer un echange.',
                    ),
                  ),
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppHeroCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const AppCountBadge(label: 'Etape 1'),
                                    const Spacer(),
                                    const AppIconBadge(
                                      icon: Icons.swap_horiz_rounded,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Choisis le livre que tu proposes a ${friend.nom}',
                                  style: AppTextStyles.heading3.copyWith(
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Selectionne un livre de ta collection pour continuer.',
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final book = books[index];
                        return _CompactExchangeBookCard(
                          book: book,
                          label: 'Je propose',
                          onTap: () {
                            context.push(
                              '/exchange/pick-theirs',
                              extra: {'friend': friend, 'myBook': book},
                            );
                          },
                        );
                      }, childCount: books.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.success),
            ),
            error: (err, _) => Center(
              child: Text(
                'Erreur : $err',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactExchangeBookCard extends StatelessWidget {
  final Book book;
  final String label;
  final VoidCallback onTap;

  const _CompactExchangeBookCard({
    required this.book,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.gradientEnd,
                ),
                clipBehavior: Clip.antiAlias,
                child: book.imagePetite != null && book.imagePetite!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.imagePetite!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const _CompactBookPlaceholder(),
                      )
                    : const _CompactBookPlaceholder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              book.titre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyWhite.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 8),
            AppCountBadge(label: label),
          ],
        ),
      ),
    );
  }
}

class _CompactBookPlaceholder extends StatelessWidget {
  const _CompactBookPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 30),
    );
  }
}

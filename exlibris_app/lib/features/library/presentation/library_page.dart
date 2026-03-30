import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../books/data/books_providers.dart';
import '../../books/data/books_repository.dart';

enum LibraryTab { collection, wishlist }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  LibraryTab _selectedTab = LibraryTab.collection;

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider);
    final wishlist = ref.watch(wishlistProvider);

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Bibliotheque',
                subtitle: 'Collection et wishlist',
              ),
              const SizedBox(height: 18),
              collectionAsync.when(
                data: (collection) => _LibraryOverview(
                  collectionCount: collection.length,
                  wishlistCount: wishlist.length,
                ),
                loading: () => const _LibraryOverview(
                  collectionCount: 0,
                  wishlistCount: 0,
                  loading: true,
                ),
                error: (_, __) => _LibraryOverview(
                  collectionCount: 0,
                  wishlistCount: wishlist.length,
                ),
              ),
              const SizedBox(height: 18),
              _LibraryTabs(
                selectedTab: _selectedTab,
                onChanged: (tab) => setState(() => _selectedTab = tab),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: switch (_selectedTab) {
                  LibraryTab.collection => collectionAsync.when(
                    data: (books) => _BooksGrid(
                      books: books,
                      emptyIcon: Icons.library_books_outlined,
                      emptyTitle: 'Ta collection est encore vide.',
                      emptySubtitle: 'Ajoute des livres depuis Explorer.',
                      actionLabel: 'Retirer',
                      onAction: (book) async {
                        await ref
                            .read(booksRepositoryProvider)
                            .removeFromCollection(book.isbn);
                        ref.invalidate(collectionProvider);
                        if (context.mounted) {
                          AppToast.info(
                            context,
                            'Retire de la collection : ${book.titre}',
                          );
                        }
                      },
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.success,
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        'Erreur de chargement : $error',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                  LibraryTab.wishlist => _BooksGrid(
                    books: wishlist,
                    emptyIcon: Icons.favorite_border,
                    emptyTitle: 'Ta wishlist est vide.',
                    emptySubtitle: 'Ajoute des livres a suivre.',
                    actionLabel: 'Retirer',
                    onAction: (book) async {
                      await ref.read(wishlistProvider.notifier).remove(book);
                      if (context.mounted) {
                        AppToast.info(
                          context,
                          'Retire de la wishlist : ${book.titre}',
                        );
                      }
                    },
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryOverview extends StatelessWidget {
  final int collectionCount;
  final int wishlistCount;
  final bool loading;

  const _LibraryOverview({
    required this.collectionCount,
    required this.wishlistCount,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            title: 'Collection',
            value: loading ? '...' : '$collectionCount',
            subtitle: 'livres',
            icon: Icons.library_books_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            title: 'Wishlist',
            value: loading ? '...' : '$wishlistCount',
            subtitle: 'envies',
            icon: Icons.favorite_rounded,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: icon, color: AppColors.success),
          const SizedBox(height: 14),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading2.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  final LibraryTab selectedTab;
  final ValueChanged<LibraryTab> onChanged;

  const _LibraryTabs({required this.selectedTab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Collection',
              icon: Icons.library_books_rounded,
              selected: selectedTab == LibraryTab.collection,
              onTap: () => onChanged(LibraryTab.collection),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TabButton(
              label: 'Wishlist',
              icon: Icons.favorite_rounded,
              selected: selectedTab == LibraryTab.wishlist,
              onTap: () => onChanged(LibraryTab.wishlist),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.success.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.success : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BooksGrid extends StatelessWidget {
  final List<Book> books;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String actionLabel;
  final Future<void> Function(Book book) onAction;

  const _BooksGrid({
    required this.books,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: AppEmptyStateCard(
          icon: emptyIcon,
          title: emptyTitle,
          subtitle: emptySubtitle,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookCard(
          book: book,
          actionLabel: actionLabel,
          onAction: () => onAction(book),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _BookCard({
    required this.book,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book', extra: book),
      child: Container(
        decoration: AppDecorations.sectionCard,
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
                        httpHeaders: const {
                          'User-Agent':
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                        },
                        errorWidget: (_, __, ___) => const _BookPlaceholder(),
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.success,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const _BookPlaceholder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.titre,
              style: AppTextStyles.bodyWhite.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (book.categorie != null && book.categorie!.isNotEmpty)
                  Expanded(
                    child: Text(
                      book.categorie!,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookPlaceholder extends StatelessWidget {
  const _BookPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white.withOpacity(0.35),
        size: 38,
      ),
    );
  }
}

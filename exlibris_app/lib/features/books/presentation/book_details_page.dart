import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
import '../../../core/book_cover.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/rating.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../ratings/data/ratings_repository.dart';
import '../data/books_providers.dart';
import '../data/books_repository.dart';

final similarBooksProvider = FutureProvider.autoDispose
    .family<List<Book>, String>((ref, isbn) async {
      return ref.read(booksRepositoryProvider).getSimilarBooks(isbn);
    });

class BookDetailsPage extends ConsumerWidget {
  final Book book;

  const BookDetailsPage({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection =
        ref.watch(collectionProvider).asData?.value ?? const <Book>[];
    final wishlist = ref.watch(wishlistProvider);
    final ratingsAsync = ref.watch(myRatingsProvider);
    final similarBooksAsync = ref.watch(similarBooksProvider(book.isbn));

    final inCollection = collection.any((item) => item.isbn == book.isbn);
    final inWishlist = wishlist.any((item) => item.isbn == book.isbn);

    Rating? myRating;
    ratingsAsync.whenData((ratings) {
      for (final rating in ratings) {
        if (rating.isbn == book.isbn) {
          myRating = rating;
          break;
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Fiche livre'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.heading3,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _Hero(book: book),
              const SizedBox(height: 18),
              _PrimaryActions(
                inCollection: inCollection,
                inWishlist: inWishlist,
                rating: myRating,
                onCollectionTap: () async {
                  try {
                    if (inCollection) {
                      await ref
                          .read(booksRepositoryProvider)
                          .removeFromCollection(book.isbn);
                      if (context.mounted) {
                        AppToast.info(context, 'Retire de la collection');
                      }
                    } else {
                      await ref
                          .read(booksRepositoryProvider)
                          .addToCollection(book.isbn);
                      if (context.mounted) {
                        AppToast.success(context, 'Ajouté à la collection');
                      }
                    }
                    ref.invalidate(collectionProvider);
                  } catch (error) {
                    if (context.mounted) {
                      AppToast.error(context, 'Erreur : $error');
                    }
                  }
                },
                onWishlistTap: () async {
                  final notifier = ref.read(wishlistProvider.notifier);
                  if (inWishlist) {
                    await notifier.remove(book);
                    if (context.mounted) {
                      AppToast.info(context, 'Retire de la wishlist');
                    }
                  } else {
                    await notifier.add(book);
                    if (context.mounted) {
                      AppToast.success(context, 'Ajouté à la wishlist');
                    }
                  }
                },
                onRatingTap: () => _openRatingDialog(
                  context,
                  ref,
                  book,
                  myRating?.note ?? 5,
                  myRating?.avis,
                ),
              ),
              const SizedBox(height: 18),
              _InfoCard(book: book, rating: myRating),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Resume',
                child: Text(
                  (book.resume != null && book.resume!.trim().isNotEmpty)
                      ? book.resume!
                      : 'Aucun resume disponible pour le moment.',
                  style: AppTextStyles.body.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 18),
              _SimilarBooksSection(similarBooksAsync: similarBooksAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimilarBooksSection extends StatelessWidget {
  final AsyncValue<List<Book>> similarBooksAsync;

  const _SimilarBooksSection({required this.similarBooksAsync});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Livres similaires',
      child: similarBooksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return Text(
              'Aucune suggestion similaire pour le moment.',
              style: AppTextStyles.body,
            );
          }

          return SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _SimilarBookCard(book: books[index]);
              },
            ),
          );
        },
        loading: () => const SizedBox(
          height: 96,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.success,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => Text(
          'Impossible de charger les livres similaires.',
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _SimilarBookCard extends StatelessWidget {
  final Book book;

  const _SimilarBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book', extra: book),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              height: 156,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.gradientEnd,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: BookCover(imageUrl: book.imagePetite, iconSize: 28),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                book.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyWhite.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Book book;

  const _Hero({required this.book});

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 118,
            height: 176,
            decoration: BoxDecoration(
              color: AppColors.gradientEnd,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BookCover(imageUrl: book.imagePetite, iconSize: 38),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.titre,
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.accent,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (book.categorie != null && book.categorie!.isNotEmpty)
                  AppCountBadge(
                    label: book.categorie!,
                    color: AppColors.accent,
                  ),
                const SizedBox(height: 12),
                Text('ISBN ${book.isbn}', style: AppTextStyles.caption),
                if (book.editeur != null && book.editeur!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(book.editeur!, style: AppTextStyles.caption),
                ],
                if (book.langue != null && book.langue!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(book.langue!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  final bool inCollection;
  final bool inWishlist;
  final Rating? rating;
  final VoidCallback onCollectionTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onRatingTap;

  const _PrimaryActions({
    required this.inCollection,
    required this.inWishlist,
    required this.rating,
    required this.onCollectionTap,
    required this.onWishlistTap,
    required this.onRatingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: inCollection
                ? Icons.library_add_check_rounded
                : Icons.library_add_rounded,
            label: inCollection ? 'Collection' : 'Ajouter',
            tone: AppColors.success,
            active: inCollection,
            onTap: onCollectionTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: inWishlist
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: inWishlist ? 'Wishlist' : 'Souhait',
            tone: AppColors.error,
            active: inWishlist,
            onTap: onWishlistTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: rating != null
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            label: rating != null ? '${rating!.note}/10' : 'Noter',
            tone: Colors.amber,
            active: rating != null,
            onTap: onRatingTap,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;
  final bool active;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.tone,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? tone.withOpacity(0.16)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? tone.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? tone : Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? tone : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Book book;
  final Rating? rating;

  const _InfoCard({required this.book, required this.rating});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'A retenir',
      child: Column(
        children: [
          _InfoRow(
            label: 'Etat',
            value: rating != null
                ? 'Tu as déjà noté ce livre'
                : 'Prêt à être ajouté',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Categorie',
            value: (book.categorie != null && book.categorie!.isNotEmpty)
                ? book.categorie!
                : 'Non renseignee',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Langue',
            value: (book.langue != null && book.langue!.isNotEmpty)
                ? book.langue!
                : 'Non renseignee',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: AppTextStyles.caption)),
        Expanded(child: Text(value, style: AppTextStyles.bodyWhite)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

void _openRatingDialog(
  BuildContext context,
  WidgetRef ref,
  Book book,
  int initialNote,
  String? initialAvis,
) {
  var note = initialNote;
  final avisController = TextEditingController(text: initialAvis);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppColors.gradientEnd,
            title: Text(
              'Noter "${book.titre}"',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Note : ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Expanded(
                      child: Slider(
                        value: note.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$note',
                        activeColor: AppColors.success,
                        onChanged: (value) {
                          setStateDialog(() {
                            note = value.round();
                          });
                        },
                      ),
                    ),
                    Text(
                      '$note/10',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avisController,
                  style: const TextStyle(color: Colors.white),
                  decoration: AppDecorations.inputDecoration(label: 'Avis'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.gradientEnd,
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(ratingsRepositoryProvider)
                        .addOrUpdateRating(
                          isbn: book.isbn,
                          note: note,
                          avis: avisController.text.trim().isEmpty
                              ? null
                              : avisController.text.trim(),
                        );
                    ref.invalidate(myRatingsProvider);
                    if (!dialogContext.mounted || !context.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    AppToast.success(context, 'Note enregistree');
                  } catch (error) {
                    if (context.mounted) {
                      AppToast.error(context, 'Erreur : $error');
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/rating.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../ratings/data/ratings_repository.dart';
import '../data/books_providers.dart';
import '../data/books_repository.dart';

class BookDetailsPage extends ConsumerWidget {
  final Book book;

  const BookDetailsPage({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection =
        ref.watch(collectionProvider).asData?.value ?? const <Book>[];
    final wishlist = ref.watch(wishlistProvider);
    final ratingsAsync = ref.watch(myRatingsProvider);

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
                        AppToast.success(context, 'Ajoute a la collection');
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
                      AppToast.success(context, 'Ajoute a la wishlist');
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
            ],
          ),
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
            child: book.imagePetite != null && book.imagePetite!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: book.imagePetite!,
                    fit: BoxFit.cover,
                    httpHeaders: const {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                    },
                    errorWidget: (_, __, ___) => const _CoverFallback(),
                  )
                : const _CoverFallback(),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.titre,
                  style: AppTextStyles.heading2.copyWith(height: 1.15),
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
                ? 'Tu as deja note ce livre'
                : 'Pret a etre ajoute',
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white.withOpacity(0.28),
        size: 38,
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

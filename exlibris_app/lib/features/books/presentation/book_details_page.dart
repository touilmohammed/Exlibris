import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/rating.dart';
import '../data/books_providers.dart';
import '../data/books_repository.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../ratings/data/ratings_repository.dart';

class BookDetailsPage extends ConsumerWidget {
  final Book book;

  const BookDetailsPage({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionProvider);
    final wishlist = ref.watch(wishlistProvider);
    final myRatingsAsync = ref.watch(myRatingsProvider);

    final bool inCollection = collectionAsync.value?.any((b) => b.isbn == book.isbn) ?? false;
    final bool inWishlist = wishlist.any((b) => b.isbn == book.isbn);
    
    Rating? myRating;
    if (myRatingsAsync.hasValue) {
      try {
        myRating = myRatingsAsync.value!.firstWhere((r) => r.isbn == book.isbn);
      } catch (_) {}
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Détails du livre'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white), // keeping this line I added earlier
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                       width: 120,
                       height: 180,
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         color: AppColors.cardBackground,
                         image: book.imagePetite != null && book.imagePetite!.isNotEmpty
                             ? DecorationImage(
                                 image: NetworkImage(book.imagePetite!),
                                 fit: BoxFit.cover,
                               )
                             : null,
                         boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5), 
                              blurRadius: 10, 
                              offset: const Offset(0, 5)
                            )
                         ]
                       ),
                       child: (book.imagePetite == null || book.imagePetite!.isEmpty)
                           ? const Icon(Icons.book, size: 48, color: Colors.white24) 
                           : null,
                     ),
                     const SizedBox(width: 24),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             book.titre,
                             style: AppTextStyles.heading2,
                           ),
                           const SizedBox(height: 8),
                           Text(
                             book.auteur,
                             style: AppTextStyles.body.copyWith(
                               fontSize: 18, 
                               color: AppColors.accent,
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                           const SizedBox(height: 12),
                           if (book.categorie != null)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: AppColors.cardBackground,
                                 borderRadius: BorderRadius.circular(20),
                                 border: Border.all(color: AppColors.cardBorder),
                               ),
                               child: Text(
                                 book.categorie!,
                                 style: const TextStyle(color: Colors.white70, fontSize: 12),
                               ),
                             ),
                            const SizedBox(height: 8),
                            Text(
                              'ISBN: ${book.isbn}',
                              style: AppTextStyles.caption,
                            ),
                            if (book.editeur != null) ...[
                               const SizedBox(height: 4),
                               Text(
                                 'Éditeur: ${book.editeur}',
                                 style: AppTextStyles.caption,
                               ),
                            ],
                            if (book.langue != null) ...[
                               const SizedBox(height: 4),
                               Text(
                                 'Langue: ${book.langue}',
                                 style: AppTextStyles.caption,
                               ),
                            ],
                         ],
                       ),
                     )
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: inCollection ? Icons.library_add_check : Icons.library_add,
                      label: inCollection ? 'Collection' : 'Ma Collection',
                      color: inCollection ? AppColors.success : Colors.white,
                      onTap: () async {
                        try {
                          if (inCollection) {
                            await ref.read(booksRepositoryProvider).removeFromCollection(book.isbn);
                            if (context.mounted) {
                              AppToast.success(context, "Retiré de la collection");
                            }
                          } else {
                            await ref.read(booksRepositoryProvider).addToCollection(book.isbn);
                            if (context.mounted) {
                              AppToast.success(context, "Ajouté à la collection");
                            }
                          }
                          ref.invalidate(collectionProvider);
                        } catch (e) {
                          if (context.mounted) {
                            AppToast.error(context, "Erreur: $e");
                          }
                        }
                      },
                    ),
                    _ActionButton(
                      icon: inWishlist ? Icons.favorite : Icons.favorite_border,
                      label: inWishlist ? 'Wishlist' : 'Ma Wishlist',
                      color: inWishlist ? AppColors.error : Colors.white,
                      onTap: () async {
                        final notifier = ref.read(wishlistProvider.notifier);
                        if (inWishlist) {
                          await notifier.remove(book);
                          if (context.mounted) {
                            AppToast.success(context, "Retiré de la wishlist");
                          }
                        } else {
                          await notifier.add(book);
                          if (context.mounted) {
                            AppToast.success(context, "Ajouté à la wishlist");
                          }
                        }
                      },
                    ),
                    _ActionButton(
                      icon: myRating != null ? Icons.star : Icons.star_border,
                      label: myRating != null ? '${myRating!.note}/10' : 'Noter',
                      color: myRating != null ? Colors.amber : Colors.white,
                      onTap: () => _openRatingDialog(context, ref, book, myRating?.note ?? 5, myRating?.avis),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (book.resume != null && book.resume!.isNotEmpty) ...[
                  const Text("Résumé", style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  Text(
                    book.resume!,
                    style: AppTextStyles.body.copyWith(height: 1.5),
                  ),
                ] else
                  const Text(
                    "Aucun résumé disponible.",
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openRatingDialog(BuildContext context, WidgetRef ref, Book book, int initialNote, String? initialAvis) {
  int note = initialNote;
  final TextEditingController avisController = TextEditingController(text: initialAvis);

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
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
                    const Text('Note : ', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: note.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$note',
                        activeColor: AppColors.success,
                        onChanged: (v) {
                          setStateDialog(() {
                            note = v.round();
                          });
                        },
                      ),
                    ),
                    Text('$note/10', style: const TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avisController,
                  style: const TextStyle(color: Colors.white),
                  decoration: AppDecorations.inputDecoration(
                    label: 'Avis (optionnel)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.gradientEnd,
                ),
                onPressed: () async {
                  try {
                    await ref.read(ratingsRepositoryProvider).addOrUpdateRating(
                          isbn: book.isbn,
                          note: note,
                          avis: avisController.text.trim().isEmpty
                              ? null
                              : avisController.text.trim(),
                        );

                    ref.invalidate(myRatingsProvider);

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        AppToast.success(context, 'Note enregistrée pour "${book.titre}"');
                      }
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      AppToast.error(context, "Erreur : $e");
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

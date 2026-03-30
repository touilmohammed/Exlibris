import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/rating.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../ratings/data/ratings_repository.dart';
import '../data/books_providers.dart';
import '../data/books_repository.dart';
import 'barcode_scanner_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _queryController = TextEditingController();
  bool _loading = false;
  List<Book> _results = [];
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _scanIsbn() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scanned == null || scanned.trim().isEmpty) {
      return;
    }

    String numeric = scanned.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) {
      AppToast.warning(context, 'Code scanne invalide');
      return;
    }

    numeric = numeric.length == 13 ? _convertIsbn13To10(numeric) : numeric;
    _queryController.text = numeric;
    await _runSearch();
  }

  String _convertIsbn13To10(String isbn13) {
    final cleanIsbn = isbn13.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanIsbn.length != 13) {
      throw Exception('Longueur invalide');
    }
    if (!cleanIsbn.startsWith('978')) {
      throw Exception('Conversion ISBN impossible');
    }

    final core = cleanIsbn.substring(3, 12);
    var sum = 0;
    for (var index = 0; index < core.length; index++) {
      sum += int.parse(core[index]) * (10 - index);
    }

    final mod = sum % 11;
    final checkDigitValue = 11 - mod;
    final checkDigit = switch (checkDigitValue) {
      10 => 'X',
      11 => '0',
      _ => checkDigitValue.toString(),
    };
    return '$core$checkDigit';
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(booksRepositoryProvider);
      final isIsbn = RegExp(r'^\d{9,13}$').hasMatch(query);
      final books = isIsbn
          ? await repo.searchBooks(isbn: query)
          : await repo.searchBooks(query: query);

      if (!mounted) {
        return;
      }
      setState(() {
        _results = books;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur de recherche : $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleCollection(Book book, bool inCollection) async {
    try {
      final repo = ref.read(booksRepositoryProvider);
      if (inCollection) {
        await repo.removeFromCollection(book.isbn);
        if (mounted) {
          AppToast.info(context, 'Retire de ta collection');
        }
      } else {
        await repo.addToCollection(book.isbn);
        if (mounted) {
          AppToast.success(context, 'Ajoute a ta collection');
        }
      }
      ref.invalidate(collectionProvider);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Erreur lors de la modification');
      }
    }
  }

  Future<void> _toggleWishlist(Book book, bool inWishlist) async {
    final notifier = ref.read(wishlistProvider.notifier);
    if (inWishlist) {
      await notifier.remove(book);
      if (mounted) {
        AppToast.info(context, 'Retire de la wishlist');
      }
    } else {
      await notifier.add(book);
      if (mounted) {
        AppToast.success(context, 'Ajoute a la wishlist');
      }
    }
  }

  Future<void> _openRatingDialog(Book book) async {
    Rating? existing;
    try {
      final list = await ref.read(myRatingsProvider.future);
      for (final rating in list) {
        if (rating.isbn == book.isbn) {
          existing = rating;
          break;
        }
      }
    } catch (_) {
      existing = null;
    }

    if (!mounted) {
      return;
    }

    var note = existing?.note ?? 0;
    final avisController = TextEditingController(text: existing?.avis ?? '');

    await showDialog<void>(
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
                      if (!mounted || !dialogContext.mounted) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      AppToast.success(context, 'Note enregistree');
                    } catch (error) {
                      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final collection =
        ref.watch(collectionProvider).asData?.value ?? const <Book>[];

    final myRatings = <String, Rating>{};
    ref
        .watch(myRatingsProvider)
        .when(
          data: (ratings) {
            for (final rating in ratings) {
              myRatings[rating.isbn] = rating;
            }
          },
          loading: () {},
          error: (_, __) {},
        );

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const AppPageHeader(
              title: 'Explorer',
              subtitle: 'Recherche, scan et decouverte',
            ),
            const SizedBox(height: 18),
            AppSurfaceCard(
              child: Column(
                children: [
                  TextField(
                    controller: _queryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AppDecorations.inputDecoration(
                      label: 'Titre, auteur ou ISBN',
                      prefixIcon: Icons.search_rounded,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Scanner',
                            onPressed: _loading ? null : _scanIsbn,
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white70,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lancer la recherche',
                            onPressed: _loading ? null : _runSearch,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _HintChip(label: 'Titre'),
                      SizedBox(width: 8),
                      _HintChip(label: 'Auteur'),
                      SizedBox(width: 8),
                      _HintChip(label: 'ISBN'),
                    ],
                  ),
                ],
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: AppColors.cardBackground,
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: AppDecorations.sectionCard,
                padding: const EdgeInsets.all(14),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: AppSectionHeader(title: 'Resultats')),
                if (_results.isNotEmpty)
                  AppCountBadge(label: '${_results.length}'),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.explore_rounded,
                title: 'Lance une recherche ou scanne un livre.',
                subtitle: 'Tes resultats apparaitront ici.',
              )
            else
              ..._results.map((book) {
                final inWishlist = wishlist.any(
                  (item) => item.isbn == book.isbn,
                );
                final inCollection = collection.any(
                  (item) => item.isbn == book.isbn,
                );
                final rating = myRatings[book.isbn];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SearchResultCard(
                    book: book,
                    inCollection: inCollection,
                    inWishlist: inWishlist,
                    rating: rating,
                    onCollectionTap: () =>
                        _toggleCollection(book, inCollection),
                    onWishlistTap: () => _toggleWishlist(book, inWishlist),
                    onRatingTap: () => _openRatingDialog(book),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;

  const _HintChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Book book;
  final bool inCollection;
  final bool inWishlist;
  final Rating? rating;
  final VoidCallback onCollectionTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onRatingTap;

  const _SearchResultCard({
    required this.book,
    required this.inCollection,
    required this.inWishlist,
    required this.rating,
    required this.onCollectionTap,
    required this.onWishlistTap,
    required this.onRatingTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book', extra: book),
      child: Container(
        decoration: AppDecorations.sectionCard,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 74,
              height: 108,
              decoration: BoxDecoration(
                color: AppColors.gradientEnd,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: book.imagePetite != null && book.imagePetite!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: book.imagePetite!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _SearchCoverFallback(),
                    )
                  : const _SearchCoverFallback(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    style: AppTextStyles.bodyWhite.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.categorie != null && book.categorie!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        book.categorie!,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionPill(
                        active: inCollection,
                        icon: inCollection
                            ? Icons.library_add_check_rounded
                            : Icons.library_add_rounded,
                        label: inCollection ? 'Collection' : 'Ajouter',
                        tone: AppColors.success,
                        onTap: onCollectionTap,
                      ),
                      _ActionPill(
                        active: inWishlist,
                        icon: inWishlist
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: inWishlist ? 'Wishlist' : 'Souhait',
                        tone: AppColors.error,
                        onTap: onWishlistTap,
                      ),
                      _ActionPill(
                        active: rating != null,
                        icon: rating != null
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        label: rating != null ? '${rating!.note}/10' : 'Noter',
                        tone: Colors.amber,
                        onTap: onRatingTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  const _ActionPill({
    required this.active,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? tone.withOpacity(0.16)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? tone.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? tone : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
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

class _SearchCoverFallback extends StatelessWidget {
  const _SearchCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        size: 34,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }
}

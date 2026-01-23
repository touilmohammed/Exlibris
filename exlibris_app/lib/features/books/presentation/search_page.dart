import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../books/data/books_repository.dart';
import '../../books/data/books_providers.dart';
import '../../../models/book.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../../models/rating.dart';
import '../../ratings/data/ratings_repository.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
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

    if (scanned == null || scanned.trim().isEmpty) return;

    String numeric = scanned.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeric.isEmpty) {
      AppToast.warning(context, 'Code scanné invalide');
      return;
    }

    numeric = numeric.length == 13 ? convertIsbn13To10(numeric) : numeric;

    _queryController.text = numeric;
    await _runSearch();
  }

  String convertIsbn13To10(String isbn13) {
    // 1. Nettoyage
    String cleanIsbn = isbn13.replaceAll(RegExp(r'[\s-]'), '');

    // 2. Vérification de faisabilité
    if (cleanIsbn.length != 13) throw Exception("Longueur invalide");
    if (!cleanIsbn.startsWith("978")) {
      throw Exception(
        "Seuls les ISBN commençant par 978 peuvent être convertis",
      );
    }

    // 3. On extrait les 9 chiffres centraux (on enlève '978' et le dernier chiffre)
    String core = cleanIsbn.substring(3, 12);

    // 4. Calcul de la clé de contrôle Modulo 11
    // Somme pondérée de 10 à 2
    int sum = 0;
    for (int i = 0; i < core.length; i++) {
      sum += int.parse(core[i]) * (10 - i);
    }

    int mod = sum % 11;
    int checkDigitValue = 11 - mod;

    String checkDigit;
    if (checkDigitValue == 10) {
      checkDigit = "X";
    } else if (checkDigitValue == 11) {
      checkDigit = "0";
    } else {
      checkDigit = checkDigitValue.toString();
    }

    return "$core$checkDigit";
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
      final q = _queryController.text.trim();
      List<Book> books;

      final isIsbn = RegExp(r'^\d{9,13}$').hasMatch(q);

      if (isIsbn) {
        books = await repo.searchBooks(isbn: q);
      } else {
        books = await repo.searchBooks(query: q);
      }

      setState(() {
        _results = books;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de recherche : $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleCollection(Book book, bool inCollection) async {
    try {
      final repo = ref.read(booksRepositoryProvider);

      if (inCollection) {
        await repo.removeFromCollection(book.isbn);
        if (mounted) {
          AppToast.info(context, 'Retiré de ta collection');
        }
      } else {
        await repo.addToCollection(book.isbn);
        if (mounted) {
          AppToast.success(context, 'Ajouté à ta collection !');
        }
      }

      ref.invalidate(collectionProvider);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Erreur lors de la modification');
    }
  }

  void _toggleWishlist(Book book) {
    final wishlist = ref.read(wishlistProvider);
    final notifier = ref.read(wishlistProvider.notifier);

    final exists = wishlist.any((b) => b.isbn == book.isbn);

    if (exists) {
      notifier.remove(book);
      AppToast.info(context, 'Retiré de la wishlist');
    } else {
      notifier.add(book);
      AppToast.success(context, 'Ajouté à la wishlist !');
    }
  }

  Future<void> _openRatingDialog(Book book) async {
    Rating? existing;
    try {
      final list = await ref.read(myRatingsProvider.future);
      for (final r in list) {
        if (r.isbn == book.isbn) {
          existing = r;
          break;
        }
      }
    } catch (_) {
      existing = null;
    }

    int note = existing?.note ?? 0;
    final avisController = TextEditingController(text: existing?.avis ?? '');

    await showDialog(
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

                      if (mounted) {
                        Navigator.of(ctx).pop();
                        AppToast.success(context, 'Note enregistrée pour "${book.titre}"');
                      }
                    } catch (e) {
                      if (!mounted) return;
                      AppToast.error(context, 'Erreur lors de l\'enregistrement : $e');
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

    final myRatingsAsync = ref.watch(myRatingsProvider);
    final Map<String, Rating> myRatings = {};

    myRatingsAsync.when(
      data: (list) {
        for (final r in list) {
          myRatings[r.isbn] = r;
        }
      },
      loading: () {},
      error: (err, stack) {},
    );

    final collectionAsync = ref.watch(collectionProvider);
    final collection = collectionAsync.asData?.value ?? const <Book>[];

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text('Explorer', style: AppTextStyles.heading2),
              const SizedBox(height: 4),
              Text(
                'Recherche un livre par titre, auteur ou ISBN',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),

              // Search field
              TextField(
                controller: _queryController,
                style: const TextStyle(color: Colors.white),
                decoration: AppDecorations.inputDecoration(
                  label: 'Rechercher...',
                  prefixIcon: Icons.search,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Scanner le code-barres',
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                        onPressed: _loading ? null : _scanIsbn,
                      ),
                      IconButton(
                        tooltip: 'Rechercher',
                        icon: const Icon(Icons.arrow_forward, color: Colors.white70),
                        onPressed: _loading ? null : _runSearch,
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
              const SizedBox(height: 16),

              if (_loading)
                LinearProgressIndicator(
                  backgroundColor: AppColors.cardBackground,
                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Results
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun résultat pour le moment.\nLance une recherche.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final book = _results[index];

                          final inWishlist = wishlist.any((b) => b.isbn == book.isbn);
                          final inCollection = collection.any((b) => b.isbn == book.isbn);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: AppDecorations.cardDecoration,
                            child: ListTile(
                              onTap: () => context.push('/book', extra: book),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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
                                          book.titre.isNotEmpty
                                              ? book.titre[0].toUpperCase()
                                              : '?',
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
                                '${book.auteur}'
                                '${book.categorie != null ? ' · ${book.categorie}' : ''}',
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Rate
                                  IconButton(
                                    tooltip: 'Noter ce livre',
                                    icon: Icon(
                                      Icons.star_rate,
                                      color: (myRatings[book.isbn]?.note ?? 0) > 0
                                          ? Colors.amber
                                          : Colors.white38,
                                      size: 22,
                                    ),
                                    onPressed: () => _openRatingDialog(book),
                                  ),

                                  // Collection
                                  IconButton(
                                    tooltip: inCollection
                                        ? 'Retirer de ma collection'
                                        : 'Ajouter à ma collection',
                                    icon: Icon(
                                      inCollection
                                          ? Icons.library_add_check
                                          : Icons.library_add,
                                      color: inCollection
                                          ? AppColors.success
                                          : Colors.white38,
                                      size: 22,
                                    ),
                                    onPressed: () => _toggleCollection(book, inCollection),
                                  ),

                                  // Wishlist
                                  IconButton(
                                    tooltip: inWishlist
                                        ? 'Retirer de ma wishlist'
                                        : 'Ajouter à ma wishlist',
                                    icon: Icon(
                                      inWishlist ? Icons.favorite : Icons.favorite_border,
                                      color: inWishlist ? AppColors.error : Colors.white38,
                                      size: 22,
                                    ),
                                    onPressed: () => _toggleWishlist(book),
                                  ),
                                ],
                              ),
                            ),
                          );
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

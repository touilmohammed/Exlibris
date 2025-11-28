import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/books_repository.dart';
import '../../books/data/books_providers.dart';
import '../../../models/book.dart';
import '../../ratings/data/ratings_providers.dart';
import '../../../models/rating.dart';
import '../../ratings/data/ratings_repository.dart';
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
    // Ouvre la page de scan et récupère le code
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    // Si l’utilisateur a annulé, on ne fait rien
    if (scanned == null || scanned.trim().isEmpty) return;

    // On garde uniquement les chiffres (certains scanners renvoient des trucs comme "ISBN 978...").
    final numeric = scanned.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeric.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code scanné invalide')));
      return;
    }

    // On met l’ISBN dans le champ de recherche
    _queryController.text = numeric;

    // Et on lance la recherche : ton _runSearch gère déjà l’ISBN 👍
    await _runSearch();
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

      // On détecte si la recherche ressemble à un ISBN (que des chiffres, 9 à 13 caractères)
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
        // déjà dans la collection → on retire
        await repo.removeFromCollection(book.isbn);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Retiré de ta collection : ${book.titre}')),
          );
        }
      } else {
        // pas dans la collection → on ajoute
        await repo.addToCollection(book.isbn);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ajouté à ta collection : ${book.titre}')),
          );
        }
      }

      // Rafraîchir la collection
      ref.invalidate(collectionProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur collection : $e')));
    }
  }

  void _toggleWishlist(Book book) {
    final wishlist = ref.read(wishlistProvider);
    final notifier = ref.read(wishlistProvider.notifier);

    // ✅ On test par ISBN, pas par instance
    final exists = wishlist.any((b) => b.isbn == book.isbn);

    if (exists) {
      notifier.remove(book);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retiré de la wishlist : ${book.titre}')),
      );
    } else {
      notifier.add(book);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajouté à la wishlist : ${book.titre}')),
      );
    }
  }

  Future<void> _openRatingDialog(Book book) async {
    // Récupérer la note existante (s’il y en a une)
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
        // 👇 StatefulBuilder pour avoir un setState propre au dialogue
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text('Noter "${book.titre}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Note : '),
                      Expanded(
                        child: Slider(
                          value: note.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: '$note',
                          onChanged: (v) {
                            setStateDialog(() {
                              note = v.round();
                            });
                          },
                        ),
                      ),
                      Text('$note/10'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: avisController,
                    decoration: const InputDecoration(
                      labelText: 'Avis (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
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

                      // On force le rechargement des notes
                      ref.invalidate(myRatingsProvider);

                      if (mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Note enregistrée pour "${book.titre}"',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur lors de l’enregistrement : $e'),
                        ),
                      );
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _queryController,
            decoration: InputDecoration(
              labelText: 'Rechercher par titre, auteur, ISBN…',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Scanner le code-barres',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _loading ? null : _scanIsbn,
                  ),
                  IconButton(
                    tooltip: 'Rechercher',
                    icon: const Icon(Icons.search),
                    onPressed: _loading ? null : _runSearch,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun résultat pour le moment.\nLance une recherche.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final book = _results[index];

                      // ✅ On check wishlist/collection par ISBN
                      final inWishlist = wishlist.any(
                        (b) => b.isbn == book.isbn,
                      );
                      final inCollection = collection.any(
                        (b) => b.isbn == book.isbn,
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              book.titre.isNotEmpty
                                  ? book.titre[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(book.titre),
                          subtitle: Text(
                            '${book.auteur}'
                            '${book.categorie != null ? ' · ${book.categorie}' : ''}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              // ⭐ Noter le livre
                              IconButton(
                                tooltip: 'Noter ce livre',
                                icon: Icon(
                                  Icons.star_rate,
                                  color: (myRatings[book.isbn]?.note ?? 0) > 0
                                      ? Colors.amber
                                      : null,
                                ),
                                onPressed: () => _openRatingDialog(book),
                              ),

                              // 📚 Collection
                              IconButton(
                                tooltip: inCollection
                                    ? 'Retirer de ma collection'
                                    : 'Ajouter à ma collection',
                                icon: Icon(
                                  inCollection
                                      ? Icons.library_add_check
                                      : Icons.library_add,
                                  color: inCollection
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                onPressed: () =>
                                    _toggleCollection(book, inCollection),
                              ),

                              // ❤️ Wishlist
                              IconButton(
                                tooltip: inWishlist
                                    ? 'Retirer de ma wishlist'
                                    : 'Ajouter à ma wishlist',
                                icon: Icon(
                                  inWishlist
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: inWishlist ? Colors.red : null,
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
    );
  }
}

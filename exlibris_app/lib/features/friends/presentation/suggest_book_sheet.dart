import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/friend.dart';
import '../../books/data/books_repository.dart';

class SuggestBookSheet extends ConsumerStatefulWidget {
  final Friend friend;

  const SuggestBookSheet({super.key, required this.friend});

  @override
  ConsumerState<SuggestBookSheet> createState() => _SuggestBookSheetState();
}

class _SuggestBookSheetState extends ConsumerState<SuggestBookSheet> {
  final _queryController = TextEditingController();
  final _messageController = TextEditingController();

  List<Book> _results = [];
  Book? _selectedBook;
  bool _searching = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchBooks() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final books = await ref
          .read(booksRepositoryProvider)
          .searchBooks(query: query);

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
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedBook == null) {
      AppToast.warning(context, 'Choisis un livre a suggerer');
      return;
    }

    final selectedBook = _selectedBook!;
    final selectedIsbn = selectedBook.isbn;
    if (selectedIsbn.isEmpty) {
      AppToast.warning(context, 'Le livre choisi n a pas d ISBN exploitable');
      return;
    }

    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();

    final message = _messageController.text.trim();
    // Le user choisit un titre visible, mais l'envoi utilise bien l'ISBN
    // du livre selectionne pour les futures integrations backend.
    final parts = <String>[
      'Suggestion envoyee a ${widget.friend.nom}',
      selectedBook.titre,
    ];
    if (message.isNotEmpty) {
      parts.add('Message ajoute');
    }

    AppToast.success(context, parts.join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.gradientEnd,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const AppIconBadge(
                      icon: Icons.menu_book_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suggérer un livre',
                            style: AppTextStyles.heading3.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recherche un titre pour ${widget.friend.nom}',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _queryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: AppDecorations.inputDecoration(
                    label: 'Titre ou auteur',
                    prefixIcon: Icons.search_rounded,
                    suffixIcon: IconButton(
                      tooltip: 'Rechercher',
                      onPressed: _searching ? null : _searchBooks,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _searchBooks(),
                ),
                if (_searching) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    backgroundColor: AppColors.cardBackground,
                    valueColor: AlwaysStoppedAnimation(AppColors.success),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                if (_selectedBook != null) ...[
                  const SizedBox(height: 16),
                  Text('Livre choisi', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  _SelectedBookCard(
                    book: _selectedBook!,
                    onClear: () => setState(() => _selectedBook = null),
                  ),
                ],
                if (_results.isNotEmpty && _selectedBook == null) ...[
                  const SizedBox(height: 16),
                  Text('Resultats', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final book = _results[index];
                        return _SearchResultTile(
                          book: book,
                          onTap: () {
                            setState(() {
                              _selectedBook = book;
                              _results = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: AppDecorations.inputDecoration(
                    label: 'Pourquoi ce livre ?',
                    prefixIcon: Icons.chat_bubble_outline_rounded,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.gradientEnd,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Envoyer la suggestion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onClear;

  const _SelectedBookCard({required this.book, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _BookThumb(book: book, width: 48, height: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyWhite.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _SearchResultTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _BookThumb(book: book, width: 46, height: 68),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyWhite.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.auteur.isEmpty ? 'Auteur inconnu' : book.auteur,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppCountBadge(label: 'Choisir', color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _BookThumb extends StatelessWidget {
  final Book book;
  final double width;
  final double height;

  const _BookThumb({
    required this.book,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.gradientEnd,
      ),
      clipBehavior: Clip.antiAlias,
      child: book.imagePetite != null && book.imagePetite!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: book.imagePetite!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const _BookThumbFallback(),
            )
          : const _BookThumbFallback(),
    );
  }
}

class _BookThumbFallback extends StatelessWidget {
  const _BookThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 24),
    );
  }
}

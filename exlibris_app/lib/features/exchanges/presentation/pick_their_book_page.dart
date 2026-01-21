import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/book.dart';
import '../../../models/friend.dart';
import '../data/exchanges_providers.dart';
import '../data/exchanges_repository.dart';

class PickTheirBookPage extends ConsumerStatefulWidget {
  final Friend friend;
  final Book myBook;

  const PickTheirBookPage({
    super.key,
    required this.friend,
    required this.myBook,
  });

  @override
  ConsumerState<PickTheirBookPage> createState() => _PickTheirBookPageState();
}

class _PickTheirBookPageState extends ConsumerState<PickTheirBookPage> {
  bool _submitting = false;

  Future<void> _processExchange(Book theirBook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.gradientEnd,
        title: const Text('Confirmer l\'échange',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Tu proposes :\n"${widget.myBook.titre}"\n\nContre :\n"${theirBook.titre}"',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(exchangesRepositoryProvider);
      await repo.createExchange(
        destinataireId: widget.friend.id,
        livreDemandeurIsbn: widget.myBook.isbn,
        livreDestinataireIsbn: theirBook.isbn,
      );

      if (!mounted) return;
      AppToast.success(context, 'Échange proposé avec succès !');

      // Retour à l'accueil (ou liste amis)
      context.go('/home'); 
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitting) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theirCollectionAsync =
        ref.watch(friendCollectionProvider(widget.friend.id));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('Je reçois (de ${widget.friend.nom})...'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: theirCollectionAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Text(
                '${widget.friend.nom} n\'a aucun livre dans sa collection.',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final hasImage =
                  book.imagePetite != null && book.imagePetite!.isNotEmpty;

              return InkWell(
                onTap: () => _processExchange(book),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.cardBackground,
                          image: hasImage
                              ? DecorationImage(
                                  image: NetworkImage(book.imagePetite!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasImage
                            ? const Center(
                                child: Icon(Icons.book,
                                    color: Colors.white24, size: 32),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erreur: $err',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

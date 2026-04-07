import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirmer la proposition',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu proposes', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(widget.myBook.titre, style: AppTextStyles.bodyWhite),
            const SizedBox(height: 14),
            Text('Tu demandes', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(theirBook.titre, style: AppTextStyles.bodyWhite),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(exchangesRepositoryProvider);
      await repo.createExchange(
        destinataireId: widget.friend.id,
        livreDemandeurIsbn: widget.myBook.isbn,
        livreDestinataireIsbn: theirBook.isbn,
      );

      if (!mounted) {
        return;
      }

      AppToast.success(context, 'Echange propose avec succes');
      context.go('/home');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'Erreur : $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theirCollectionAsync = ref.watch(
      friendCollectionProvider(widget.friend.id),
    );

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
          child: Stack(
            children: [
              theirCollectionAsync.when(
                data: (books) {
                  if (books.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: AppEmptyStateCard(
                          icon: Icons.inventory_2_outlined,
                          title:
                              '${widget.friend.nom} n a aucun livre a proposer.',
                          subtitle:
                              'Tu pourras lancer un echange quand sa collection sera remplie.',
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
                            children: [
                              AppHeroCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const AppCountBadge(label: 'Etape 2'),
                                        const Spacer(),
                                        const AppIconBadge(
                                          icon: Icons.check_circle_outline,
                                          color: AppColors.accent,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Choisis le livre que tu souhaites recevoir',
                                      style: AppTextStyles.heading3.copyWith(
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tu proposes "${widget.myBook.titre}" a ${widget.friend.nom}.',
                                      style: AppTextStyles.body,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              AppSurfaceCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    _MiniCover(book: widget.myBook),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Livre propose',
                                            style: AppTextStyles.caption,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.myBook.titre,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyWhite
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
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
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final book = books[index];
                            return _ExchangeTargetCard(
                              book: book,
                              onTap: () => _processExchange(book),
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
              if (_submitting)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.success),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeTargetCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ExchangeTargetCard({required this.book, required this.onTap});

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
            const AppCountBadge(label: 'Je recois', color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  final Book book;

  const _MiniCover({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.gradientEnd,
      ),
      clipBehavior: Clip.antiAlias,
      child: book.imagePetite != null && book.imagePetite!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: book.imagePetite!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const _CompactBookPlaceholder(),
            )
          : const _CompactBookPlaceholder(),
    );
  }
}

class _CompactBookPlaceholder extends StatelessWidget {
  const _CompactBookPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 28),
    );
  }
}

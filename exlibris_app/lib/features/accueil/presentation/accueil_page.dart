import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../models/book.dart';
import '../../../models/exchange.dart';
import '../../auth/data/auth_repository.dart';
import '../../books/data/books_providers.dart';
import '../../books/data/books_repository.dart';
import '../../exchanges/data/exchanges_providers.dart';
import '../../friends/data/friends_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';

final homeRecommendationsProvider = FutureProvider<List<Book>>((ref) async {
  try {
    return await ref.read(booksRepositoryProvider).getRecommendations();
  } catch (_) {
    return [];
  }
});

final homeProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.read(profileRepositoryProvider).getMyProfile();
});

class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(homeProfileProvider);
    final collectionAsync = ref.watch(collectionProvider);
    final recommendationsAsync = ref.watch(homeRecommendationsProvider);
    final exchangesAsync = ref.watch(myExchangesProvider);
    final friendsAsync = ref.watch(friendsListProvider);

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _Header(profileAsync: profileAsync),
            const SizedBox(height: 18),
            _PrimaryCard(
              exchangesAsync: exchangesAsync,
              collectionAsync: collectionAsync,
              friendsAsync: friendsAsync,
            ),
            const SizedBox(height: 18),
            _SectionBlock(
              title: 'Bibliotheque',
              trailing: collectionAsync.asData?.value.isNotEmpty == true
                  ? AppCountBadge(
                      label: '${collectionAsync.asData!.value.length}',
                    )
                  : null,
              child: collectionAsync.when(
                data: (books) => _BookStrip(
                  books: books.take(5).toList(),
                  emptyLabel: 'Ajoute tes premiers livres depuis Explorer.',
                ),
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(message: 'Erreur : $error'),
              ),
            ),
            const SizedBox(height: 18),
            _SectionBlock(
              title: 'Pour toi',
              trailing: recommendationsAsync.asData?.value.isNotEmpty == true
                  ? AppCountBadge(
                      label: '${recommendationsAsync.asData!.value.length}',
                      color: AppColors.accent,
                    )
                  : null,
              child: recommendationsAsync.when(
                data: (books) => _BookStrip(
                  books: books.take(5).toList(),
                  emptyLabel: 'Les recommandations apparaitront ici.',
                ),
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(message: 'Erreur : $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final AsyncValue<UserProfile> profileAsync;

  const _Header({required this.profileAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = profileAsync.asData?.value.nomUtilisateur ?? 'lecteur';

    return AppPageHeader(
      title: 'Bonjour, $username',
      subtitle: 'Ton espace du moment',
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'logout') {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) {
              AppRouter.goSignIn(context);
            }
          } else if (value == 'profile') {
            context.push('/profile');
          }
        },
        color: const Color(0xFF1A3A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'profile',
            child: Text('Mon profil', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem<String>(
            value: 'logout',
            child: Text('Deconnexion', style: TextStyle(color: Colors.white)),
          ),
        ],
        child: const _ProfileMenuTrigger(),
      ),
    );
  }
}

class _ProfileMenuTrigger extends StatelessWidget {
  const _ProfileMenuTrigger();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  final AsyncValue<List<Exchange>> exchangesAsync;
  final AsyncValue<List<Book>> collectionAsync;
  final AsyncValue<List<dynamic>> friendsAsync;

  const _PrimaryCard({
    required this.exchangesAsync,
    required this.collectionAsync,
    required this.friendsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final exchanges = exchangesAsync.asData?.value ?? const <Exchange>[];
    final pending = exchanges
        .where((exchange) => exchange.statut == 'demande_envoyee')
        .toList();
    final collectionCount = collectionAsync.asData?.value.length ?? 0;
    final friendsCount = friendsAsync.asData?.value.length ?? 0;

    final headline = pending.isNotEmpty
        ? 'Tu as ${pending.length} echange${pending.length > 1 ? 's' : ''} a suivre'
        : 'Ta bibliotheque est prete pour les prochains echanges';
    final detail = pending.isNotEmpty
        ? (pending.first.livreDemandeurTitre ??
              pending.first.livreDemandeurIsbn)
        : '$collectionCount livres dans ta collection · $friendsCount dans ton reseau';

    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppCountBadge(
                label: pending.isNotEmpty
                    ? 'En attente'
                    : 'Bibliotheque active',
              ),
              const Spacer(),
              const AppIconBadge(icon: Icons.auto_awesome_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: AppTextStyles.heading3.copyWith(fontSize: 22, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(detail, style: AppTextStyles.body),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '$collectionCount',
                  label: 'Collection',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(value: '$friendsCount', label: 'Reseau'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(value: '${pending.length}', label: 'Echanges'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionBlock({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title, trailing: trailing),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BookStrip extends StatelessWidget {
  final List<Book> books;
  final String emptyLabel;

  const _BookStrip({required this.books, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Text(emptyLabel, style: AppTextStyles.body),
      );
    }

    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _BookCard(book: books[index]),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book', extra: book),
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF173137),
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
                      )
                    : const _BookPlaceholder(),
              ),
            ),
            const SizedBox(height: 10),
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
              book.auteur,
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

class _BookPlaceholder extends StatelessWidget {
  const _BookPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.menu_book_rounded, color: Colors.white24),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(color: AppColors.success),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;

  const _SectionError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.sectionCard,
      padding: const EdgeInsets.all(18),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

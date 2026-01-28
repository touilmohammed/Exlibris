
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../../models/book.dart';
import '../../books/data/books_providers.dart';
import '../../books/data/books_repository.dart';
import '../../friends/data/friends_providers.dart';
import '../../../models/friend.dart';

final homeRecommendationsProvider = FutureProvider<List<Book>>((ref) async {
  try {
    final repo = ref.read(booksRepositoryProvider);
    final response = await repo.getRecommendations();
    return response;
  } catch (e) {
    return [];
  }
});

/// Page d'accueil principale ExLibris
/// (feed avec Mes livres, Recommandation IA, Mes amis)
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBooksAsync = ref.watch(collectionProvider);
    final recommendationsAsync = ref.watch(homeRecommendationsProvider);
    final friendsAsync = ref.watch(friendsListProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF02191D),
            Color(0xFF051E24),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Mes livres',
                child: myBooksAsync.when(
                  data: (books) => books.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("Aucun livre dans ta collection.", style: TextStyle(color: Colors.white70)),
                        )
                      : _BooksCarousel(books: books.take(10).toList()),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text("Erreur: $e", style: const TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Recommandation IA',
                child: recommendationsAsync.when(
                  data: (books) => books.isEmpty
                      ? const Text("Aucune recommandation.", style: TextStyle(color: Colors.white70))
                      : _BooksCarousel(books: books.take(10).toList()),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text("Erreur: $e", style: const TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Mes amis',
                child: friendsAsync.when(
                  data: (friends) => friends.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("Aucun ami ajouté.", style: TextStyle(color: Colors.white70)),
                        )
                      : _FriendsStrip(friends: friends),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text("Erreur: $e", style: const TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête avec logo/nom de l'app et avatar utilisateur
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ExLibris',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bienvenue dans ta biblio',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) AppRouter.goSignIn(context);
            } else if (value == 'profile') {
              context.push('/profile');
            }
          },
          color: const Color(0xFF1A3A3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text('Mon Profil', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text('Déconnexion', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte de section arrondie avec fond sombre/verre
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Bandeau horizontal de livres
class _BooksCarousel extends StatelessWidget {
  final List<Book> books;

  const _BooksCarousel({required this.books});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final book = books[index];
          return _BookCard(book: book);
        },
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: InkWell(
        onTap: () => context.push('/book', extra: book),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1F2933),
            image: (book.imagePetite != null && book.imagePetite!.isNotEmpty)
                ? DecorationImage(
                    image: CachedNetworkImageProvider(
                      book.imagePetite!,
                      // AJOUT DU USER-AGENT POUR AMAZON
                      headers: {
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                      },
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                book.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



/// Bandeau horizontal Mes Amis
class _FriendsStrip extends StatelessWidget {
  final List<Friend> friends;

  const _FriendsStrip({required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: Text(
                      friend.nom.isNotEmpty ? friend.nom[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                friend.nom,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
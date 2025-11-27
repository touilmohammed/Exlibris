

import 'package:flutter/material.dart';

/// Page d'accueil principale ExLibris
/// (feed avec Mes livres, Recommandation IA, Mes amis)
class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              const _SectionCard(
                title: 'Mes livres',
                child: _BooksCarousel(
                  books: [
                    _BookStub('Cendres de Annie'),
                    _BookStub('Femmes du silence'),
                    _BookStub('La brume des bois'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionCard(
                title: 'Recommandation IA',
                child: _BooksCarousel(
                  books: [
                    _BookStub('Jeux sans loi'),
                    _BookStub('This is the first poem I wrote'),
                    _BookStub('My Heart Bleeds Ink'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionCard(
                title: 'Mes amis',
                child: _FriendsStrip(
                  friends: [
                    _FriendStub('Meli'),
                    _FriendStub('TIMoche'),
                    _FriendStub('Eve'),
                  ],
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
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.2,
            ),
            image: const DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage('assets/images/avatar_placeholder.png'),
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

/// Modèle simplifié pour représenter un livre (placeholder)
class _BookStub {
  final String title;
  const _BookStub(this.title);
}

/// Bandeau horizontal de livres
class _BooksCarousel extends StatelessWidget {
  final List<_BookStub> books;

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
          return _BookCard(title: book.title);
        },
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;

  const _BookCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1F2933),
              Color(0xFF111827),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
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
    );
  }
}

/// Modèle simplifié pour un ami
class _FriendStub {
  final String name;
  const _FriendStub(this.name);
}

/// Bandeau horizontal Mes Amis
class _FriendsStrip extends StatelessWidget {
  final List<_FriendStub> friends;

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
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage(
                      'assets/images/avatar_placeholder.png',
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
                friend.name,
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
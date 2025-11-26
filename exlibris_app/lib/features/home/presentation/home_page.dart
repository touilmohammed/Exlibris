import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../books/presentation/search_page.dart';
import '../../books/presentation/collection_page.dart';
import '../../books/presentation/wishlist_page.dart';
import '../../friends/presentation/friends_page.dart';
import '../../../app_router.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Explorer, Collection, Souhaits, Amis
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ExLibris'),
          actions: [
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) AppRouter.goSignIn(context);
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.search), text: 'Explorer'),
              Tab(icon: Icon(Icons.library_books), text: 'Collection'),
              Tab(icon: Icon(Icons.favorite), text: 'Souhaits'),
              Tab(icon: Icon(Icons.people), text: 'Amis'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Onglet 1 : recherche de livres
            SearchPage(),
            // Onglet 2 : collection de l’utilisateur
            CollectionPage(),
            // Onglet 3 : wishlist
            WishlistPage(),
            // Onglet 4 : Amis
            FriendsPage(),
          ],
        ),
      ),
    );
  }
}

class FriendsPlaceholderPage extends StatelessWidget {
  const FriendsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Fonctionnalités amis / suggestions\nà implémenter plus tard.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

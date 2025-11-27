import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../books/presentation/search_page.dart';
import '../../books/presentation/collection_page.dart';
import '../../books/presentation/wishlist_page.dart';
import '../../friends/presentation/friends_page.dart';
import '../../accueil/presentation/accueil_page.dart';
import '../../../app_router.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  List<Widget> get _pages => const [
    AccueilPage(),
    SearchPage(),
    CollectionPage(),
    WishlistPage(),
    FriendsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _currentIndex == 0
          ? null
          : AppBar(
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
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _pages[_currentIndex],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: LiquidGlassLayer(
                  child: LiquidGlass(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 26),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xD9FFFFFF),
                            const Color(0x99FFFFFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _GlassNavItem(
                            index: 0,
                            currentIndex: _currentIndex,
                            icon: Icons.home,
                            label: 'Accueil',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 1,
                            currentIndex: _currentIndex,
                            icon: Icons.library_books,
                            label: 'Collection',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 2,
                            currentIndex: _currentIndex,
                            icon: Icons.favorite,
                            label: 'Souhaits',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 3,
                            currentIndex: _currentIndex,
                            icon: Icons.people,
                            label: 'Amis',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 4,
                            currentIndex: _currentIndex,
                            icon: Icons.search,
                            label: 'Explorer',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _GlassNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  const _GlassNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isActive ? 26 : 22,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

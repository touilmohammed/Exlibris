import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../books/presentation/search_page.dart';
import '../../books/presentation/collection_page.dart';
import '../../books/presentation/wishlist_page.dart';
import '../../friends/presentation/friends_page.dart';
import '../../accueil/presentation/accueil_page.dart';
import '../../../app_router.dart';
import '../../../core/app_theme.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  // Pages matching navigation order
  List<Widget> get _pages => const [
        AccueilPage(),     // 0: Accueil
        CollectionPage(),  // 1: Collection
        WishlistPage(),    // 2: Souhaits
        FriendsPage(),     // 3: Amis
        SearchPage(),      // 4: Explorer
      ];

  void _logout() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) AppRouter.goSignIn(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Page content
          Positioned.fill(
            child: _pages[_currentIndex],
          ),

          // Bottom navigation
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
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
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
                            icon: Icons.home_rounded,
                            label: 'Accueil',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 1,
                            currentIndex: _currentIndex,
                            icon: Icons.library_books_rounded,
                            label: 'Collection',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 2,
                            currentIndex: _currentIndex,
                            icon: Icons.favorite_rounded,
                            label: 'Souhaits',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 3,
                            currentIndex: _currentIndex,
                            icon: Icons.people_rounded,
                            label: 'Amis',
                            onTap: (i) => setState(() => _currentIndex = i),
                          ),
                          _GlassNavItem(
                            index: 4,
                            currentIndex: _currentIndex,
                            icon: Icons.search_rounded,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.success.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: isActive ? 24 : 22,
                color: isActive ? AppColors.success : Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.success : Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../core/app_theme.dart';
import '../../accueil/presentation/accueil_page.dart';
import '../../books/presentation/search_page.dart';
import '../../exchanges/presentation/exchanges_page.dart';
import '../../friends/presentation/friends_page.dart';
import '../../library/presentation/library_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    AccueilPage(),
    LibraryPage(),
    ExchangesPage(),
    FriendsPage(),
    SearchPage(),
  ];

  static const List<_NavItemData> _items = [
    _NavItemData(Icons.home_rounded, 'Accueil'),
    _NavItemData(Icons.bookmarks_rounded, 'Bibliotheque'),
    _NavItemData(Icons.swap_horiz_rounded, 'Echanges'),
    _NavItemData(Icons.people_rounded, 'Reseau'),
    _NavItemData(Icons.search_rounded, 'Explorer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _pages[_currentIndex],
              ),
            ),
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
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth =
                              constraints.maxWidth / _items.length;
                          return Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                left: (_currentIndex * itemWidth) + 8,
                                top: 8,
                                width: itemWidth - 16,
                                height: 60,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.success.withValues(
                                            alpha: 0.22,
                                          ),
                                          AppColors.accent.withValues(
                                            alpha: 0.12,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.success.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.success.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: List.generate(_items.length, (index) {
                                  final item = _items[index];
                                  return _GlassNavItem(
                                    index: index,
                                    currentIndex: _currentIndex,
                                    icon: item.icon,
                                    label: item.label,
                                    onTap: (value) {
                                      if (value == _currentIndex) {
                                        return;
                                      }
                                      setState(() => _currentIndex = value);
                                    },
                                  );
                                }),
                              ),
                            ],
                          );
                        },
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
    final isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: isActive ? 1 : 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final activeColor = Color.lerp(
                    Colors.white.withValues(alpha: 0.62),
                    AppColors.success,
                    value,
                  )!;
                  return Transform.translate(
                    offset: Offset(0, -1.5 * value),
                    child: Icon(
                      icon,
                      size: 22 + (2 * value),
                      color: activeColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.success
                      : Colors.white.withValues(alpha: 0.62),
                  letterSpacing: isActive ? 0.1 : 0,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData(this.icon, this.label);
}

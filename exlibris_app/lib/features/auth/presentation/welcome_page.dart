import 'package:flutter/material.dart';

import '../../../app_router.dart';
import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => AppRouter.goSignIn(context),
                    child: const Text(
                      'Connexion',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const Spacer(),
                AppHeroCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 42,
                          color: Color(0xFF1A3A3A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ExLibris',
                        style: AppTextStyles.heading1.copyWith(
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ta bibliotheque sociale pour decouvrir, partager et echanger des livres.',
                        style: AppTextStyles.body.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          AppCountBadge(label: 'Collection'),
                          AppCountBadge(
                            label: 'Echanges',
                            color: AppColors.accent,
                          ),
                          AppCountBadge(
                            label: 'Recommandations',
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const AppSurfaceCard(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeatureRow(
                        icon: Icons.library_books_rounded,
                        title: 'Organise ta collection',
                        subtitle:
                            'Retrouve tes livres et ta wishlist au meme endroit.',
                      ),
                      SizedBox(height: 14),
                      _FeatureRow(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Propose des echanges',
                        subtitle:
                            'Lance des propositions simplement avec ton reseau.',
                      ),
                      SizedBox(height: 14),
                      _FeatureRow(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Decouvre de nouvelles lectures',
                        subtitle:
                            'Profite des suggestions et des livres similaires.',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => AppRouter.goSignUp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.gradientEnd,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text("Creer un compte"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => AppRouter.goSignIn(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Se connecter'),
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(icon: icon, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyWhite.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

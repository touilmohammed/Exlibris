import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../books/data/books_providers.dart';
import '../../exchanges/data/exchanges_providers.dart';
import '../../friends/data/friends_providers.dart';
import '../../ratings/data/ratings_providers.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        AppToast.error(context, 'Erreur de chargement du profil');
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).signOut();

    ref.invalidate(collectionProvider);
    ref.invalidate(wishlistProvider);
    ref.invalidate(myExchangesProvider);
    ref.invalidate(friendsListProvider);
    ref.invalidate(incomingFriendRequestsProvider);
    ref.invalidate(outgoingFriendRequestsProvider);
    ref.invalidate(myRatingsProvider);

    if (mounted) {
      context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Mon profil'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Se deconnecter',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.success),
      );
    }

    if (_error != null || _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger le profil',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        _ProfileHero(profile: profile),
        const SizedBox(height: 20),
        _StatGrid(profile: profile),
        const SizedBox(height: 20),
        _ProfileSection(
          title: 'Confiance et activite',
          subtitle: 'Ton activite actuelle',
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.swap_horiz_rounded,
                title: 'Echanges',
                value: profile.nbLivresCollection > 0
                    ? 'Collection active'
                    : 'Ajoute des livres pour commencer',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.people_rounded,
                title: 'Reseau',
                value: profile.nbAmis > 0
                    ? '${profile.nbAmis} ami${profile.nbAmis > 1 ? 's' : ''} dans ton espace ExLibris.'
                    : 'Commence a construire ton reseau de lecteurs.',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.favorite_rounded,
                title: 'Intentions',
                value: profile.nbLivresWishlist > 0
                    ? '${profile.nbLivresWishlist} envie${profile.nbLivresWishlist > 1 ? 's' : ''} a surveiller dans ta wishlist.'
                    : 'Ta wishlist est vide pour le moment.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ProfileSection(
          title: 'Acces rapides',
          subtitle: 'Continuer',
          child: Column(
            children: [
              _QuickLink(
                icon: Icons.swap_horiz_rounded,
                label: 'Voir mes echanges',
                onTap: () => context.push('/my-exchanges'),
              ),
              const SizedBox(height: 10),
              _QuickLink(
                icon: Icons.library_books_rounded,
                label: 'Retour a la bibliotheque',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;

  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(profile.nomUtilisateur, style: AppTextStyles.heading2),
          const SizedBox(height: 6),
          Text(profile.email, style: AppTextStyles.body),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Profil lecteur actif',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final UserProfile profile;

  const _StatGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Collection',
            value: '${profile.nbLivresCollection}',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Wishlist',
            value: '${profile.nbLivresWishlist}',
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Reseau',
            value: '${profile.nbAmis}',
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.sectionCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(fontSize: 24, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.body),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accent),
        ),
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
              Text(value, style: AppTextStyles.caption.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyWhite)),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

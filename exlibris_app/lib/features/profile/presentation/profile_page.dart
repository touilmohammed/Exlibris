import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

import '../../books/data/books_providers.dart';
import '../../exchanges/data/exchanges_providers.dart';
import '../../friends/data/friends_providers.dart';
import '../../ratings/data/ratings_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.nomUtilisateur;
          _emailController.text = profile.email;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        AppToast.error(context, "Erreur de chargement du profil");
      }
    }
  }

  Future<void> _logout() async {
    // 1. Déconnexion via le repo (suppression du token)
    await ref.read(authRepositoryProvider).signOut();

    // 2. Invalider tous les providers utilisateurs pour vider le cache/état
    ref.invalidate(collectionProvider);
    ref.invalidate(wishlistProvider);
    ref.invalidate(myExchangesProvider);
    ref.invalidate(friendsListProvider);
    ref.invalidate(incomingFriendRequestsProvider);
    ref.invalidate(outgoingFriendRequestsProvider);
    ref.invalidate(myRatingsProvider);

    // 3. Redirection
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.pageBackground,
        child: SafeArea(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Impossible de charger le profil",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _loadProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text("Réessayer"),
            ),
          ],
        ),
      );
    }
    if (_profile == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            style: AppTextStyles.heading2,
            readOnly: !_isEditing,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Nom d'utilisateur",
              hintStyle: const TextStyle(color: Colors.white24),
              border: _isEditing
                  ? const UnderlineInputBorder()
                  : InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            style: AppTextStyles.body,
            keyboardType: TextInputType.emailAddress,
            readOnly: !_isEditing,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Email",
              hintStyle: const TextStyle(color: Colors.white24),
              border: _isEditing
                  ? const UnderlineInputBorder()
                  : InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: _buildEditButton()),
          const SizedBox(height: 48),
          _buildStatsRow(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz, color: AppColors.accent),
              label: const Text(
                'Mes propositions',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => context.push('/my-exchanges'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.person, size: 64, color: Colors.white),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem("Collection", _profile!.nbLivresCollection.toString()),
        _buildStatItem("Wishlist", _profile!.nbLivresWishlist.toString()),
        _buildStatItem("Amis", _profile!.nbAmis.toString()),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return ElevatedButton.icon(
      icon: Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.black),
      label: Text(
        _isEditing ? 'Enregistrer' : 'Modifier le profil',
        style: const TextStyle(color: Colors.black),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _isSaving
          ? null
          : () async {
              if (_isEditing) {
                // Sauvegarder
                setState(() => _isSaving = true);
                try {
                  await ref
                      .read(profileRepositoryProvider)
                      .updateProfile(
                        nomUtilisateur: _nameController.text,
                        email: _emailController.text,
                      );
                  // Rafraîchir
                  await _loadProfile();
                  if (mounted) {
                    setState(() {
                      _isEditing = false;
                    });
                    AppToast.success(context, "Profil mis à jour");
                  }
                } catch (e) {
                  if (mounted) {
                    AppToast.error(context, "Erreur lors de la mise à jour");
                  }
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              } else {
                setState(() => _isEditing = true);
              }
            },
    );
  }
}

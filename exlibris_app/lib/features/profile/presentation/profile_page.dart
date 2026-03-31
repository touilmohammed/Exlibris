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
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _ageController;
  String? _selectedSexe;
  String? _selectedPays;

  final List<String> _sexeOptions = const [
    'Homme',
    'Femme',
    'Non binaire',
    'Non precise',
    'Autre',
  ];

  final List<String> _paysOptions = const [
    'France',
    'Belgique',
    'Suisse',
    'Canada',
    'Algerie',
    'Maroc',
    'Tunisie',
    'Senegal',
    'Cote d Ivoire',
    'Cameroun',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _ageController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getMyProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _applyProfileToForm(profile);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      AppToast.error(context, 'Erreur de chargement du profil');
    }
  }

  void _applyProfileToForm(UserProfile profile) {
    _nameController.text = profile.nomUtilisateur;
    _emailController.text = profile.email;
    _ageController.text = profile.age?.toString() ?? '';
    _selectedSexe = switch (profile.sexe) {
      'male' => 'Homme',
      'femelle' => 'Femme',
      'indefini' => 'Non precise',
      final value => value,
    };
    _selectedPays = profile.pays;
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

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String apiSexe = 'indefini';
      if (_selectedSexe == 'Homme') {
        apiSexe = 'male';
      } else if (_selectedSexe == 'Femme') {
        apiSexe = 'femelle';
      }

      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            nomUtilisateur: _nameController.text.trim(),
            email: _emailController.text.trim(),
            age: int.tryParse(_ageController.text),
            sexe: apiSexe,
            pays: _selectedPays,
          );

      await _loadProfile();
      if (!mounted) {
        return;
      }
      setState(() => _isEditing = false);
      AppToast.success(context, 'Profil mis a jour');
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Erreur lors de la mise a jour');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    if (_profile != null) {
      _applyProfileToForm(_profile!);
    }
    setState(() => _isEditing = false);
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
        _EditableProfileSection(
          isEditing: _isEditing,
          isSaving: _isSaving,
          nameController: _nameController,
          emailController: _emailController,
          ageController: _ageController,
          selectedSexe: _selectedSexe,
          selectedPays: _selectedPays,
          sexeOptions: _sexeOptions,
          paysOptions: _paysOptions,
          onSexeChanged: (value) => setState(() => _selectedSexe = value),
          onPaysChanged: (value) => setState(() => _selectedPays = value),
          onStartEdit: () => setState(() => _isEditing = true),
          onCancel: _cancelEdit,
          onSave: _saveProfile,
        ),
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
                    ? '${profile.nbLivresWishlist} envie${profile.nbLivresWishlist > 1 ? 's' : ''} a surveiller.'
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
                icon: Icons.volunteer_activism_rounded,
                label: 'Faire un don',
                onTap: () => context.push('/donate'),
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

class _EditableProfileSection extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController ageController;
  final String? selectedSexe;
  final String? selectedPays;
  final List<String> sexeOptions;
  final List<String> paysOptions;
  final ValueChanged<String?> onSexeChanged;
  final ValueChanged<String?> onPaysChanged;
  final VoidCallback onStartEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditableProfileSection({
    required this.isEditing,
    required this.isSaving,
    required this.nameController,
    required this.emailController,
    required this.ageController,
    required this.selectedSexe,
    required this.selectedPays,
    required this.sexeOptions,
    required this.paysOptions,
    required this.onSexeChanged,
    required this.onPaysChanged,
    required this.onStartEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Mes informations',
      subtitle: isEditing ? 'Modifie puis sauvegarde' : 'Infos de ton compte',
      child: Column(
        children: [
          _FieldRow(
            label: 'Nom',
            child: TextFormField(
              controller: nameController,
              readOnly: !isEditing,
              style: AppTextStyles.bodyWhite,
              decoration: _inputDecoration(isEditing, 'Nom utilisateur'),
            ),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: 'Email',
            child: TextFormField(
              controller: emailController,
              readOnly: !isEditing,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.bodyWhite,
              decoration: _inputDecoration(isEditing, 'Email'),
            ),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: 'Age',
            child: TextFormField(
              controller: ageController,
              readOnly: !isEditing,
              keyboardType: TextInputType.number,
              style: AppTextStyles.bodyWhite,
              decoration: _inputDecoration(isEditing, 'Non renseigne'),
            ),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: 'Sexe',
            child: isEditing
                ? DropdownButtonFormField<String>(
                    initialValue: selectedSexe,
                    dropdownColor: AppColors.backgroundDark,
                    style: AppTextStyles.bodyWhite,
                    items: sexeOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: onSexeChanged,
                    decoration: _inputDecoration(isEditing, 'Non renseigne'),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedSexe ?? 'Non renseigne',
                      style: AppTextStyles.bodyWhite,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: 'Pays',
            child: isEditing
                ? DropdownButtonFormField<String>(
                    initialValue: selectedPays,
                    dropdownColor: AppColors.backgroundDark,
                    style: AppTextStyles.bodyWhite,
                    items: paysOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: onPaysChanged,
                    decoration: _inputDecoration(isEditing, 'Non renseigne'),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedPays ?? 'Non renseigne',
                      style: AppTextStyles.bodyWhite,
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          if (!isEditing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Modifier le profil'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sauvegarder'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool editable, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      isDense: true,
      filled: editable,
      fillColor: editable ? Colors.white.withValues(alpha: 0.05) : null,
      border: editable
          ? const OutlineInputBorder()
          : const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white12),
            ),
      enabledBorder: editable
          ? const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            )
          : const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white12),
            ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(label, style: AppTextStyles.caption),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
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

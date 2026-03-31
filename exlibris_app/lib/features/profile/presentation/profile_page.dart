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
import '../data/payment_service.dart';

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
  late TextEditingController _ageController;
  String? _selectedSexe;
  String? _selectedPays;

  final List<String> _sexeOptions = [
    'Homme',
    'Femme',
    'Non binaire',
    'Non précisé',
    'Autre',
  ];

  final List<String> _paysOptions = [
    'France',
    'Belgique',
    'Suisse',
    'Canada',
    'Algérie',
    'Maroc',
    'Tunisie',
    'Sénégal',
    'Côte d\'Ivoire',
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
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.nomUtilisateur;
          _emailController.text = profile.email;
          _ageController.text = profile.age?.toString() ?? '';

          // Reverse mapping for sexe
          if (profile.sexe == 'male') {
            _selectedSexe = 'Homme';
          } else if (profile.sexe == 'femelle') {
            _selectedSexe = 'Femme';
          } else if (profile.sexe == 'indefini') {
            _selectedSexe = 'Non précisé'; // Default choice for indefini
          } else {
            _selectedSexe = null;
          }

          _selectedPays = profile.pays;

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

  Future<void> _showDonationSheet() async {
    int amount = 5;
    String currency = 'eur';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF00261C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Faire un don",
                    style: AppTextStyles.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Soutenez Exlibris avec un don.\nChoisissez le montant et la devise.",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: amount.toString(),
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            labelText: "Montant",
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            amount = int.tryParse(val) ?? 5;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: currency,
                        dropdownColor: AppColors.backgroundDark,
                        style: AppTextStyles.body,
                        items: const [
                          DropdownMenuItem(
                            value: 'eur',
                            child: Text('EUR (€)'),
                          ),
                          DropdownMenuItem(
                            value: 'usd',
                            child: Text('USD (\$)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => currency = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final stripeAmount = amount * 100; // in cents
                      final success = await PaymentService().makePayment(
                        stripeAmount,
                        currency,
                      );
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Merci beaucoup pour votre don ! ❤️",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "Payer",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
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
          if (_isEditing || (_profile!.age != null))
            _buildInfoRow(
              "Âge",
              TextFormField(
                controller: _ageController,
                style: AppTextStyles.body,
                keyboardType: TextInputType.number,
                readOnly: !_isEditing,
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  hintText: "Non renseigné",
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: _isEditing
                      ? const UnderlineInputBorder()
                      : InputBorder.none,
                ),
              ),
            ),
          if (_isEditing || (_profile!.sexe != null))
            _buildInfoRow(
              "Sexe",
              _isEditing
                  ? DropdownButtonFormField<String>(
                      initialValue: _selectedSexe,
                      dropdownColor: AppColors.backgroundDark,
                      style: AppTextStyles.body,
                      items: _sexeOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSexe = val),
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                    )
                  : Text(
                      _selectedSexe ?? "Non renseigné",
                      style: AppTextStyles.body,
                      textAlign: TextAlign.end,
                    ),
            ),
          if (_isEditing || (_profile!.pays != null))
            _buildInfoRow(
              "Pays",
              _isEditing
                  ? DropdownButtonFormField<String>(
                      initialValue: _selectedPays,
                      dropdownColor: AppColors.backgroundDark,
                      style: AppTextStyles.body,
                      items: _paysOptions.map((p) {
                        return DropdownMenuItem(value: p, child: Text(p));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedPays = val),
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                    )
                  : Text(
                      _selectedPays ?? "Non renseigné",
                      style: AppTextStyles.body,
                      textAlign: TextAlign.end,
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: const Text(
                'Faire un don',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _showDonationSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 32),
          Expanded(child: content),
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
    if (!_isEditing) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.edit, color: Colors.black),
        label: const Text(
          'Modifier le profil',
          style: TextStyle(color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () => setState(() => _isEditing = true),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close, color: Colors.white70),
            label: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      _isEditing = false;
                      // Remettre les données de base
                      if (_profile != null) {
                        _nameController.text = _profile!.nomUtilisateur;
                        _emailController.text = _profile!.email;
                        _ageController.text = _profile!.age?.toString() ?? '';

                        // Reset sexe
                        if (_profile!.sexe == 'male') {
                          _selectedSexe = 'Homme';
                        } else if (_profile!.sexe == 'femelle') {
                          _selectedSexe = 'Femme';
                        } else if (_profile!.sexe == 'indefini') {
                          _selectedSexe = 'Non précisé';
                        } else {
                          _selectedSexe = null;
                        }

                        _selectedPays = _profile!.pays;
                      }
                    });
                  },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.black),
            label: const Text(
              'Sauvegarder',
              style: TextStyle(color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSaving
                ? null
                : () async {
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
                            nomUtilisateur: _nameController.text,
                            email: _emailController.text,
                            age: int.tryParse(_ageController.text),
                            sexe: apiSexe,
                            pays: _selectedPays,
                          );
                      await _loadProfile();
                      if (mounted) {
                        setState(() => _isEditing = false);
                        AppToast.success(context, "Profil mis à jour");
                      }
                    } catch (e) {
                      if (mounted) {
                        AppToast.error(
                          context,
                          "Erreur lors de la mise à jour",
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
          ),
        ),
      ],
    );
  }
}

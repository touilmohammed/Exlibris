import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../friends/data/friends_repository.dart';
import '../../../core/app_theme.dart';
import 'suggest_book_sheet.dart';
import '../../exchanges/data/exchanges_repository.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  bool _loading = false;
  String? _error;

  List<Friend> _friends = [];
  List<Friend> _incoming = [];
  List<Friend> _outgoing = [];
  List<Friend> _searchResults = [];

  final _searchController = TextEditingController();

  FriendsRepository get _repo => ref.read(friendsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = _repo;
      final friends = await repo.getFriends();
      final incoming = await repo.getIncomingRequests();
      final outgoing = await repo.getOutgoingRequests();

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur chargement amis : $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept(Friend friend) async {
    setState(() => _loading = true);
    try {
      await _repo.acceptRequest(friend.id);
      if (!mounted) return;
      setState(() {
        _incoming.removeWhere((f) => f.id == friend.id);
        if (!_friends.any((f) => f.id == friend.id)) {
          _friends.add(friend);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande acceptée : ${friend.nom}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur acceptation : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refuse(Friend friend) async {
    setState(() => _loading = true);
    try {
      await _repo.refuseRequest(friend.id);
      if (!mounted) return;
      setState(() {
        _incoming.removeWhere((f) => f.id == friend.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande refusée : ${friend.nom}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur refus : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.gradientEnd,
        title: const Text(
          'Supprimer cet ami ?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tu ne seras plus ami avec ${friend.nom}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _repo.removeFriend(friend.id);
      if (!mounted) return;
      setState(() {
        _friends.removeWhere((f) => f.id == friend.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ami supprimé : ${friend.nom}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doSearch() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _repo.search(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur recherche amis : $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(Friend friend) async {
    setState(() => _loading = true);
    try {
      await _repo.sendRequest(friend.id);
      if (!mounted) return;
      setState(() {
        _searchResults.removeWhere((f) => f.id == friend.id);
        if (!_outgoing.any((f) => f.id == friend.id)) {
          _outgoing.add(friend);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande envoyée à ${friend.nom}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi demande : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSuggestSheet(Friend friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.gradientEnd,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SuggestBookSheet(friend: friend),
    );
  }

  Future<void> _openExchangeDialog(Friend friend) async {
    final myIsbnController = TextEditingController();
    final theirIsbnController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.gradientEnd,
          title: Text(
            'Proposer un échange à ${friend.nom}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: myIsbnController,
                style: const TextStyle(color: Colors.white),
                decoration: AppDecorations.inputDecoration(
                  label: 'Ton livre (ISBN)',
                  prefixIcon: Icons.book,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: theirIsbnController,
                style: const TextStyle(color: Colors.white),
                decoration: AppDecorations.inputDecoration(
                  label: 'Livre de ${friend.nom} (ISBN)',
                  prefixIcon: Icons.book_outlined,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.gradientEnd,
              ),
              onPressed: () async {
                final myIsbn = myIsbnController.text.trim();
                final theirIsbn = theirIsbnController.text.trim();

                if (myIsbn.isEmpty || theirIsbn.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Merci de remplir les deux ISBN.')),
                  );
                  return;
                }

                try {
                  final repo = ref.read(exchangesRepositoryProvider);
                  await repo.createExchange(
                    destinataireId: friend.id,
                    livreDemandeurIsbn: myIsbn,
                    livreDestinataireIsbn: theirIsbn,
                  );

                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Échange proposé à ${friend.nom} (ton $myIsbn ↔ son $theirIsbn)',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors de la proposition d\'échange : $e')),
                  );
                }
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Proposer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.heading3),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendCard(Friend f, {required List<Widget> actions, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.gradientEnd,
          child: Text(
            f.nom.isNotEmpty ? f.nom[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(f.nom, style: AppTextStyles.bodyWhite),
        subtitle: subtitle != null ? Text(subtitle, style: AppTextStyles.caption) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.success,
          backgroundColor: AppColors.gradientEnd,
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Header
              const Text('Amis', style: AppTextStyles.heading2),
              const SizedBox(height: 4),
              Text('Gère tes amis et découvre de nouveaux contacts', style: AppTextStyles.body),

              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.cardBackground,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                ),

              // Incoming requests
              if (_incoming.isNotEmpty) ...[
                _buildSectionTitle('Demandes reçues', count: _incoming.length),
                ..._incoming.map(
                  (f) => _buildFriendCard(
                    f,
                    subtitle: 'Veut devenir ton ami',
                    actions: [
                      IconButton(
                        tooltip: 'Accepter',
                        icon: const Icon(Icons.check_circle, color: AppColors.success),
                        onPressed: () => _accept(f),
                      ),
                      IconButton(
                        tooltip: 'Refuser',
                        icon: const Icon(Icons.cancel, color: AppColors.error),
                        onPressed: () => _refuse(f),
                      ),
                    ],
                  ),
                ),
              ],

              // My friends
              _buildSectionTitle('Mes amis', count: _friends.length),
              if (_friends.isEmpty)
                Text('Tu n\'as pas encore d\'amis.', style: AppTextStyles.body)
              else
                ..._friends.map(
                  (f) => _buildFriendCard(
                    f,
                    actions: [
                      IconButton(
                        tooltip: 'Suggérer un livre',
                        icon: const Icon(Icons.menu_book, color: Colors.white54, size: 20),
                        onPressed: () => _openSuggestSheet(f),
                      ),
                      IconButton(
                        tooltip: 'Proposer un échange',
                        icon: const Icon(Icons.swap_horiz, color: Colors.white54, size: 20),
                        onPressed: () => _openExchangeDialog(f),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.person_remove, color: Colors.white38, size: 20),
                        onPressed: () => _removeFriend(f),
                      ),
                    ],
                  ),
                ),

              // Outgoing requests
              if (_outgoing.isNotEmpty) ...[
                _buildSectionTitle('Demandes envoyées'),
                ..._outgoing.map(
                  (f) => _buildFriendCard(
                    f,
                    subtitle: 'En attente de réponse',
                    actions: const [
                      Icon(Icons.hourglass_empty, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ],

              // Search section
              _buildSectionTitle('Rechercher de nouveaux amis'),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: AppDecorations.inputDecoration(
                  label: 'Nom / pseudo',
                  prefixIcon: Icons.search,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white70),
                    onPressed: _doSearch,
                  ),
                ),
                onSubmitted: (_) => _doSearch(),
              ),
              const SizedBox(height: 12),

              if (_searchResults.isEmpty)
                Text('Aucun résultat pour le moment.', style: AppTextStyles.body)
              else
                ..._searchResults.map(
                  (f) => _buildFriendCard(
                    f,
                    actions: [
                      IconButton(
                        tooltip: 'Envoyer une demande',
                        icon: const Icon(Icons.person_add, color: AppColors.success),
                        onPressed: () => _sendRequest(f),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

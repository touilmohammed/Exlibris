import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../friends/data/friends_repository.dart';
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
  List<Friend> _incoming = []; // demandes reçues
  List<Friend> _outgoing = []; // demandes envoyées
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur acceptation : $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur refus : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet ami ?'),
        content: Text('Tu ne seras plus ami avec ${friend.nom}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ami supprimé : ${friend.nom}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi demande : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSuggestSheet(Friend friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          title: Text('Proposer un échange à ${friend.nom}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: myIsbnController,
                decoration: const InputDecoration(
                  labelText: 'Ton livre (ISBN)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: theirIsbnController,
                decoration: const InputDecoration(
                  labelText: 'Livre de ${''} (ISBN)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final myIsbn = myIsbnController.text.trim();
                final theirIsbn = theirIsbnController.text.trim();

                if (myIsbn.isEmpty || theirIsbn.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Merci de remplir les deux ISBN.'),
                    ),
                  );
                  return;
                }

                try {
                  final repo = ref.read(
                    exchangesRepositoryProvider,
                  ); // 👈 nouveau
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
                    SnackBar(
                      content: Text(
                        'Erreur lors de la proposition d’échange : $e',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Proposer l’échange'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          // --- Amis actuels ---
          _buildSectionTitle('Mes amis'),
          if (_friends.isEmpty)
            const Text('Tu n’as pas encore d’amis enregistrés.')
          else
            ..._friends.map(
              (f) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(f.nom),
                  subtitle: const Text('Ami'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Suggérer un livre',
                        icon: const Icon(Icons.menu_book),
                        onPressed: () => _openSuggestSheet(f),
                      ),
                      IconButton(
                        tooltip: 'Proposer un échange',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _openExchangeDialog(f),
                      ),
                      IconButton(
                        tooltip: 'Supprimer cet ami',
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeFriend(f),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // --- Demandes reçues ---
          _buildSectionTitle('Demandes reçues'),
          if (_incoming.isEmpty)
            const Text('Aucune demande reçue pour le moment.')
          else
            ..._incoming.map(
              (f) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_add)),
                  title: Text(f.nom),
                  subtitle: const Text('Veut devenir ton ami'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Accepter',
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _accept(f),
                      ),
                      IconButton(
                        tooltip: 'Refuser',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _refuse(f),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // --- Demandes envoyées ---
          _buildSectionTitle('Demandes envoyées'),
          if (_outgoing.isEmpty)
            const Text('Aucune demande envoyée pour le moment.')
          else
            ..._outgoing.map(
              (f) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.pending_actions),
                  ),
                  title: Text(f.nom),
                  subtitle: const Text('En attente de réponse'),
                ),
              ),
            ),

          const Divider(height: 32),

          // --- Recherche de nouveaux amis ---
          _buildSectionTitle('Rechercher de nouveaux amis'),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Nom / pseudo',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _doSearch,
              ),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
          const SizedBox(height: 12),
          if (_searchResults.isEmpty)
            const Text('Aucun résultat pour le moment.')
          else
            ..._searchResults.map(
              (f) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_search)),
                  title: Text(f.nom),
                  subtitle: const Text('Suggestion'),
                  trailing: IconButton(
                    tooltip: 'Envoyer une demande',
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () => _sendRequest(f),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

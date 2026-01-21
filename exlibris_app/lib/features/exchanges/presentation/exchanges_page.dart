import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart'; // Pour context.push

import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/exchange.dart';
import '../../profile/data/profile_repository.dart';
import '../../exchanges/data/exchanges_providers.dart';
import '../../exchanges/data/exchanges_repository.dart';
import '../../books/data/books_repository.dart'; // Pour récupérer les détails du livre

class ExchangesPage extends ConsumerStatefulWidget {
  const ExchangesPage({super.key});

  @override
  ConsumerState<ExchangesPage> createState() => _ExchangesPageState();
}

class _ExchangesPageState extends ConsumerState<ExchangesPage> {
  @override
  Widget build(BuildContext context) {
    final exchangesAsync = ref.watch(myExchangesProvider);
    // On a besoin de l'ID utilisateur pour savoir si on est demandeur ou receveur
    // On peut le récupérer via le profil (déjà chargé ou via un FutureProvider)
    // Ici on va faire simple et utiliser un FutureBuilder sur getMyProfile si besoin,
    // ou mieux: on suppose que le profil est déjà dans un provider global si on l'avait fait.
    // Mais pour l'instant, faisons un simple FutureBuilder pour l'ID user si on ne l'a pas.
    // Ou mieux encore, on peut le stocker dans un provider simple au login.
    // Pour l'instant, utilisons le repo profile pour choper l'ID.

    final myProfileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Mes propositions'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: myProfileAsync.when(
        data: (profile) {
          final myId = profile.id;
          
          return exchangesAsync.when(
            data: (exchanges) {
              if (exchanges.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucune proposition en cours.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: exchanges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final exchange = exchanges[index];
                  return _ExchangeCard(exchange: exchange, myId: myId);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Impossible de charger le profil: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _ExchangeCard extends ConsumerWidget {
  final Exchange exchange;
  final int myId;

  const _ExchangeCard({required this.exchange, required this.myId});

  bool get isMeSender => exchange.expediteurId == myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Déterminer le titre/message
    // Si je suis l'expéditeur, je VEUX recevoir le livre "Destinataire" et je DONNE le livre "Demandeur"
    // Si je suis le destinataire, on me PROPOSE le livre "Demandeur" contre mon livre "Destinataire"
    
    // Simplification visuelle :
    // "Je donne: [Livre A] <-> Je reçois: [Livre B]"

    final myBookIsbn = isMeSender ? exchange.livreDemandeurIsbn : exchange.livreDestinataireIsbn;
    final theirBookIsbn = isMeSender ? exchange.livreDestinataireIsbn : exchange.livreDemandeurIsbn;

    Color statusColor = Colors.grey;
    String statusText = exchange.statut;

    switch (exchange.statut) {
      case 'demande_envoyee':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'proposition_confirmee':
      case 'demande_acceptee':
        statusColor = AppColors.success;
        statusText = 'Acceptée';
        break;
      case 'demande_refusee':
        statusColor = AppColors.error;
        statusText = 'Refusée';
        break;
      case 'annulee':
      case 'annule':
        statusColor = Colors.grey;
        statusText = 'Annulée';
        break;
    }

    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(exchange.dateEchange),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBookRow(context, ref, Icons.upload, "Je donne", myBookIsbn, isMeSender ? exchange.livreDemandeurTitre : exchange.livreDestinataireTitre),
            const SizedBox(height: 8),
            _buildBookRow(context, ref, Icons.download, "Je reçois", theirBookIsbn, isMeSender ? exchange.livreDestinataireTitre : exchange.livreDemandeurTitre),
            
            if (exchange.statut == 'demande_envoyee') ...[
              const Divider(color: Colors.white10, height: 24),
              _buildActions(context, ref),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBookRow(BuildContext context, WidgetRef ref, IconData icon, String label, String isbn, String? title) {
    return InkWell(
      onTap: () => _openBookDetails(context, ref, isbn),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text("$label: ", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Expanded(
              child: Text(
                title ?? "ISBN $isbn",
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookDetails(BuildContext context, WidgetRef ref, String isbn) async {
    // On doit récupérer les détails du livre pour ouvrir la page
    // On peut utiliser le repo pour ça
    try {
      final books = await ref.read(booksRepositoryProvider).searchBooks(isbn: isbn);
      if (books.isNotEmpty && context.mounted) {
        context.push('/book', extra: books.first);
      } else if (context.mounted) {
        AppToast.error(context, "Livre introuvable");
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, "Erreur lors du chargement du livre");
    }
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    if (isMeSender) {
      // Je peux annuler
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
          onPressed: () => _cancel(context, ref),
          child: const Text("Annuler la demande"),
        ),
      );
    } else {
      // Je peux accepter ou refuser
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => _refuse(context, ref),
              child: const Text("Refuser"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              onPressed: () => _accept(context, ref),
              child: const Text("Accepter"),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(exchangesRepositoryProvider).cancelExchange(exchange.id);
      ref.invalidate(myExchangesProvider);
      if(context.mounted) AppToast.success(context, "Demande annulée");
    } catch (e) {
      if(context.mounted) AppToast.error(context, "Erreur: $e");
    }
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(exchangesRepositoryProvider).acceptExchange(exchange.id);
      ref.invalidate(myExchangesProvider);
      if(context.mounted) AppToast.success(context, "Echange accepté !");
    } catch (e) {
      if(context.mounted) AppToast.error(context, "Erreur: $e");
    }
  }

  Future<void> _refuse(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(exchangesRepositoryProvider).refuseExchange(exchange.id);
      ref.invalidate(myExchangesProvider);
      if(context.mounted) AppToast.success(context, "Demande refusée");
    } catch (e) {
      if(context.mounted) AppToast.error(context, "Erreur: $e");
    }
  }
}

// Petit provider local pour le profil si pas dispo ailleurs
final myProfileProvider = FutureProvider.autoDispose((ref) => ref.read(profileRepositoryProvider).getMyProfile());

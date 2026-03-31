import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../models/exchange.dart';
import '../../books/data/books_repository.dart';
import '../../exchanges/data/exchanges_providers.dart';
import '../../exchanges/data/exchanges_repository.dart';
import '../../profile/data/profile_repository.dart';

enum ExchangeFilter { all, pending, completed }

final myProfileProvider = FutureProvider.autoDispose(
  (ref) => ref.read(profileRepositoryProvider).getMyProfile(),
);

class ExchangesPage extends ConsumerStatefulWidget {
  const ExchangesPage({super.key});

  @override
  ConsumerState<ExchangesPage> createState() => _ExchangesPageState();
}

class _ExchangesPageState extends ConsumerState<ExchangesPage> {
  ExchangeFilter _filter = ExchangeFilter.all;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final exchangesAsync = ref.watch(myExchangesProvider);

    return Container(
      decoration: AppDecorations.pageBackground,
      child: SafeArea(
        bottom: false,
        child: profileAsync.when(
          data: (profile) => exchangesAsync.when(
            data: (exchanges) {
              final filtered = _applyFilter(exchanges);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const AppPageHeader(
                    title: 'Echanges',
                    subtitle: 'Tes propositions et leur statut',
                  ),
                  const SizedBox(height: 18),
                  _ExchangeOverview(exchanges: exchanges),
                  const SizedBox(height: 18),
                  _ExchangeFilterBar(
                    selected: _filter,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    const _EmptyExchangeState()
                  else
                    ...filtered.map(
                      (exchange) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExchangeCard(
                          exchange: exchange,
                          myId: profile.id,
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.success),
            ),
            error: (error, _) => Center(
              child: Text(
                'Erreur de chargement : $error',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.success),
          ),
          error: (error, _) => Center(
            child: Text(
              'Impossible de charger le profil : $error',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  List<Exchange> _applyFilter(List<Exchange> exchanges) {
    return switch (_filter) {
      ExchangeFilter.all => exchanges,
      ExchangeFilter.pending =>
        exchanges
            .where((exchange) => exchange.statut == 'demande_envoyee')
            .toList(),
      ExchangeFilter.completed =>
        exchanges
            .where((exchange) => exchange.statut != 'demande_envoyee')
            .toList(),
    };
  }
}

class _ExchangeOverview extends StatelessWidget {
  final List<Exchange> exchanges;

  const _ExchangeOverview({required this.exchanges});

  @override
  Widget build(BuildContext context) {
    final pending = exchanges
        .where((e) => e.statut == 'demande_envoyee')
        .length;
    final completed = exchanges.length - pending;

    return Row(
      children: [
        Expanded(
          child: _OverviewTile(
            label: 'En attente',
            value: '$pending',
            color: AppColors.warning,
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OverviewTile(
            label: 'Valides',
            value: '$completed',
            color: AppColors.success,
            icon: Icons.verified_rounded,
          ),
        ),
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _OverviewTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Row(
        children: [
          AppIconBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.heading3.copyWith(fontSize: 22)),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExchangeFilterBar extends StatelessWidget {
  final ExchangeFilter selected;
  final ValueChanged<ExchangeFilter> onChanged;

  const _ExchangeFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _FilterButton(
            label: 'Tout',
            selected: selected == ExchangeFilter.all,
            onTap: () => onChanged(ExchangeFilter.all),
          ),
          _FilterButton(
            label: 'En attente',
            selected: selected == ExchangeFilter.pending,
            onTap: () => onChanged(ExchangeFilter.pending),
          ),
          _FilterButton(
            label: 'Valides',
            selected: selected == ExchangeFilter.completed,
            onTap: () => onChanged(ExchangeFilter.completed),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.success.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyExchangeState extends StatelessWidget {
  const _EmptyExchangeState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyStateCard(
      icon: Icons.swap_horiz_rounded,
      title: 'Aucun echange a afficher pour le moment.',
      subtitle: 'Propose un livre depuis ton reseau ou une fiche livre.',
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
    final myBookTitle = isMeSender
        ? exchange.livreDemandeurTitre
        : exchange.livreDestinataireTitre;
    final theirBookTitle = isMeSender
        ? exchange.livreDestinataireTitre
        : exchange.livreDemandeurTitre;
    final (statusLabel, statusColor) = _statusMeta(exchange.statut);

    return Container(
      decoration: AppDecorations.sectionCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy').format(exchange.dateEchange),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BookLine(
            label: 'Je donne',
            title: myBookTitle ?? exchange.livreDemandeurIsbn,
            icon: Icons.north_east_rounded,
            onTap: () => _openBookDetails(
              context,
              ref,
              isMeSender
                  ? exchange.livreDemandeurIsbn
                  : exchange.livreDestinataireIsbn,
            ),
          ),
          const SizedBox(height: 10),
          _BookLine(
            label: 'Je recois',
            title: theirBookTitle ?? exchange.livreDestinataireIsbn,
            icon: Icons.south_west_rounded,
            onTap: () => _openBookDetails(
              context,
              ref,
              isMeSender
                  ? exchange.livreDestinataireIsbn
                  : exchange.livreDemandeurIsbn,
            ),
          ),
          const SizedBox(height: 16),
          _ExchangeActions(exchange: exchange, isMeSender: isMeSender),
        ],
      ),
    );
  }

  (String, Color) _statusMeta(String status) {
    return switch (status) {
      'demande_envoyee' => ('En attente', AppColors.warning),
      'proposition_confirmee' ||
      'demande_acceptee' => ('Acceptee', AppColors.success),
      'demande_refusee' ||
      'demande_acceptee_refusee' => ('Refusee', AppColors.error),
      'annulee' || 'annule' => ('Annulee', Colors.white54),
      _ => (status, AppColors.accent),
    };
  }

  Future<void> _openBookDetails(
    BuildContext context,
    WidgetRef ref,
    String isbn,
  ) async {
    try {
      final books = await ref
          .read(booksRepositoryProvider)
          .searchBooks(isbn: isbn);
      if (books.isNotEmpty && context.mounted) {
        context.push('/book', extra: books.first);
      } else if (context.mounted) {
        AppToast.error(context, 'Livre introuvable');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Impossible de charger le livre');
      }
    }
  }
}

class _BookLine extends StatelessWidget {
  final String label;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _BookLine({
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTextStyles.bodyWhite.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeActions extends ConsumerWidget {
  final Exchange exchange;
  final bool isMeSender;

  const _ExchangeActions({required this.exchange, required this.isMeSender});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exchange.statut != 'demande_envoyee') {
      return Text('Statut archive pour suivi.', style: AppTextStyles.caption);
    }

    if (isMeSender) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.16)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            try {
              await ref
                  .read(exchangesRepositoryProvider)
                  .cancelExchange(exchange.id);
              ref.invalidate(myExchangesProvider);
              if (context.mounted) {
                AppToast.success(context, 'Demande annulee');
              }
            } catch (e) {
              if (context.mounted) {
                AppToast.error(context, 'Erreur : $e');
              }
            }
          },
          child: const Text('Annuler la demande'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              try {
                await ref
                    .read(exchangesRepositoryProvider)
                    .refuseExchange(exchange.id);
                ref.invalidate(myExchangesProvider);
                if (context.mounted) {
                  AppToast.success(context, 'Demande refusee');
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Erreur : $e');
                }
              }
            },
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              try {
                await ref
                    .read(exchangesRepositoryProvider)
                    .acceptExchange(exchange.id);
                ref.invalidate(myExchangesProvider);
                if (context.mounted) {
                  AppToast.success(context, 'Echange accepte');
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Erreur : $e');
                }
              }
            },
            child: const Text('Accepter'),
          ),
        ),
      ],
    );
  }
}

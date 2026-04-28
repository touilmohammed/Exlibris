import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../models/friend.dart';
import '../data/notifications_providers.dart';
import '../../home/presentation/home_page.dart';

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final readIds = ref.watch(readNotificationsProvider);
    final notifier = ref.read(readNotificationsProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications', style: AppTextStyles.heading2),
                if (notificationsAsync.valueOrNull?.isNotEmpty == true)
                  TextButton(
                    onPressed: () {
                      final ids = notificationsAsync.value!.map((n) => n.id).toList();
                      notifier.markAllAsRead(ids);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    child: const Text('Tout marquer comme lu'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune notification',
                      style: AppTextStyles.bodyWhite,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = readIds.contains(notification.id);

                    return _NotificationTile(
                      notification: notification,
                      isRead: isRead,
                      onTap: () {
                        notifier.markAsRead(notification.id);
                        Navigator.pop(context); // Close the sheet

                        if (notification.type == 'new_message' || notification.type == 'wishlist_match') {
                          // On redirige vers l'onglet Réseau (index 3)
                          ref.read(homeIndexProvider.notifier).state = 3;
                        } else if (notification.type == 'exchange_request') {
                          // On redirige vers l'onglet Échanges (index 2)
                          ref.read(homeIndexProvider.notifier).state = 2;
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.success),
              ),
              error: (err, stack) => Center(
                child: Text('Erreur: $err', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final dynamic notification;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'new_message':
        icon = Icons.message_rounded;
        iconColor = AppColors.accent;
        break;
      case 'wishlist_match':
        icon = Icons.favorite_rounded;
        iconColor = Colors.pinkAccent;
        break;
      case 'exchange_request':
        icon = Icons.swap_horiz_rounded;
        iconColor = AppColors.warning;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppColors.success;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead 
            ? Colors.white.withValues(alpha: 0.03) 
            : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead 
              ? Colors.transparent 
              : iconColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.bodyWhite.copyWith(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTextStyles.caption.copyWith(
                      color: isRead 
                        ? Colors.white.withValues(alpha: 0.5) 
                        : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

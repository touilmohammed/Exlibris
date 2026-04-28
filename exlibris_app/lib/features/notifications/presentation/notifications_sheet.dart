import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/book_cover.dart';
import '../../../core/app_theme.dart';
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
            child: _NotificationsHeader(
              canMarkAll:
                  notificationsAsync.valueOrNull
                      ?.any((notification) => !readIds.contains(notification.id)) ==
                  true,
              onMarkAll: () {
                final ids = notificationsAsync.value!
                    .where((notification) => !readIds.contains(notification.id))
                    .map((notification) => notification.id)
                    .toList();
                notifier.markAllAsRead(ids);
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                final unreadNotifications = notifications
                    .where((notification) => !readIds.contains(notification.id))
                    .toList();

                if (unreadNotifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune nouvelle notification',
                      style: AppTextStyles.bodyWhite,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: unreadNotifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = unreadNotifications[index];
                    final isRead = readIds.contains(notification.id);

                    return _NotificationTile(
                      notification: notification,
                      isRead: isRead,
                      onTap: () {
                        notifier.markAsRead(notification.id);
                        Navigator.pop(context); // Close the sheet

                        if (notification.type == 'new_message' ||
                            notification.type == 'wishlist_match') {
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
                child: Text(
                  'Erreur: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final bool canMarkAll;
  final VoidCallback onMarkAll;

  const _NotificationsHeader({
    required this.canMarkAll,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Text('Notifications', style: AppTextStyles.heading2),
            if (canMarkAll)
              TextButton(
                onPressed: onMarkAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isCompact ? 'Tout lu' : 'Tout marquer comme lu',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        );
      },
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
      case 'book_suggestion':
        icon = Icons.menu_book_rounded;
        iconColor = AppColors.success;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppColors.success;
    }

    final suggestion = notification.type == 'book_suggestion'
        ? _BookSuggestionData.from(notification.data)
        : null;

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
                  if (suggestion != null) ...[
                    const SizedBox(height: 10),
                    _BookSuggestionPreview(
                      suggestion: suggestion,
                      isRead: isRead,
                    ),
                  ] else if (notification.type != 'new_message') ...[
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

class _BookSuggestionData {
  final String title;
  final String author;
  final String? imageUrl;
  final String reason;

  const _BookSuggestionData({
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.reason,
  });

  factory _BookSuggestionData.from(Map<String, dynamic> data) {
    final friendName = data['friend_name']?.toString().trim() ?? 'Un ami';
    final reason = data['reason']?.toString().trim();

    return _BookSuggestionData(
      title: data['book_title']?.toString().trim() ?? 'Livre suggéré',
      author: data['book_author']?.toString().trim() ?? '',
      imageUrl: data['book_image']?.toString(),
      reason: reason == null || reason.isEmpty
          ? '$friendName pense que ce livre pourrait te plaire.'
          : reason,
    );
  }
}

class _BookSuggestionPreview extends StatelessWidget {
  final _BookSuggestionData suggestion;
  final bool isRead;

  const _BookSuggestionPreview({
    required this.suggestion,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isRead
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.86);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 46,
              height: 66,
              child: BookCover(
                imageUrl: suggestion.imageUrl,
                iconSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyWhite.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (suggestion.author.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    suggestion.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: textColor),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Pourquoi : ${suggestion.reason}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: textColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

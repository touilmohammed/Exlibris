import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/notification.dart';
import 'notifications_repository.dart';

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  
  ref.onDispose(() {
    repository.disconnect();
  });

  return repository.connect();
});

final readNotificationsProvider = StateNotifierProvider<ReadNotificationsNotifier, Set<String>>((ref) {
  return ReadNotificationsNotifier();
});

class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  static const _prefsKey = 'read_notifications_ids';
  
  ReadNotificationsNotifier() : super({}) {
    _loadReadIds();
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    state = ids.toSet();
  }

  Future<void> markAsRead(String id) async {
    if (state.contains(id)) return;
    
    final newState = {...state, id};
    state = newState;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, newState.toList());
  }

  Future<void> markAllAsRead(List<String> ids) async {
    final newState = {...state, ...ids};
    state = newState;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, newState.toList());
  }
}

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsStreamProvider);
  final readIds = ref.watch(readNotificationsProvider);

  return notificationsAsync.maybeWhen(
    data: (notifications) {
      return notifications.where((n) => !readIds.contains(n.id)).length;
    },
    orElse: () => 0,
  );
});

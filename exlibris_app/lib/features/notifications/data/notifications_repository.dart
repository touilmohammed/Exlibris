import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/env.dart';
import '../../../core/token_storage.dart';
import '../../../models/notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository();
});

class NotificationsRepository {
  WebSocketChannel? _channel;
  StreamController<List<NotificationModel>>? _notificationsController;

  Stream<List<NotificationModel>> connect() async* {
    _notificationsController = StreamController<List<NotificationModel>>.broadcast();

    final token = await TokenStorage.read();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    String wsBaseUrl = Env.apiBaseUrl;
    if (wsBaseUrl.startsWith('https://')) {
      wsBaseUrl = wsBaseUrl.replaceFirst('https://', 'wss://');
    } else if (wsBaseUrl.startsWith('http://')) {
      wsBaseUrl = wsBaseUrl.replaceFirst('http://', 'ws://');
    }
    
    final wsUrl = '$wsBaseUrl/notifications/ws?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    final List<NotificationModel> currentNotifications = [];

    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);
          final event = data['event'];

          if (event == 'init') {
            currentNotifications.clear();
            final items = data['items'] as List;
            currentNotifications.addAll(items.map((e) => NotificationModel.fromJson(e)));
            // Trier par date décroissante
            currentNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _notificationsController?.add(List.from(currentNotifications));
          } else if (event == 'notification') {
            final item = NotificationModel.fromJson(data['item']);
            currentNotifications.insert(0, item);
            _notificationsController?.add(List.from(currentNotifications));
          }
        } catch (e) {
          print('Erreur lors du parsing de la notification: $e');
        }
      },
      onError: (error) {
        print('WebSocket Erreur: $error');
        _notificationsController?.addError(error);
      },
      onDone: () {
        print('WebSocket fermé');
      },
    );

    yield* _notificationsController!.stream;
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _notificationsController?.close();
    _notificationsController = null;
  }
}

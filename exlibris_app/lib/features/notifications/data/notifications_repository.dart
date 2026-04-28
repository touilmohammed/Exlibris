import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/env.dart';
import '../../../core/token_storage.dart';
import '../../../models/notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository();
});

class NotificationsRepository {
  WebSocketChannel? _channel;
  StreamController<List<NotificationModel>>? _notificationsController;

  Stream<List<NotificationModel>> connect() async* {
    _notificationsController =
        StreamController<List<NotificationModel>>.broadcast();

    final token = await TokenStorage.read();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final wsUrl = _buildWebSocketUri(token);
    _channel = WebSocketChannel.connect(wsUrl);

    final List<NotificationModel> currentNotifications = [];

    Future<void> loadHttpFallback() async {
      try {
        final items = await _fetchNotifications(token);
        currentNotifications
          ..clear()
          ..addAll(items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _notificationsController?.add(List.from(currentNotifications));
      } catch (e) {
        debugPrint('Fallback notifications HTTP échoué: $e');
      }
    }

    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);
          final event = data['event'];

          if (event == 'init') {
            currentNotifications.clear();
            final items = data['items'] as List;
            currentNotifications.addAll(
              items.map((e) => NotificationModel.fromJson(e)),
            );
            // Trier par date décroissante
            currentNotifications.sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );
            _notificationsController?.add(List.from(currentNotifications));
          } else if (event == 'notification') {
            final item = NotificationModel.fromJson(data['item']);
            currentNotifications.insert(0, item);
            _notificationsController?.add(List.from(currentNotifications));
          }
        } catch (e) {
          debugPrint('Erreur lors du parsing de la notification: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket Erreur: $error');
        unawaited(loadHttpFallback());
      },
      onDone: () {
        debugPrint('WebSocket fermé');
        if (currentNotifications.isEmpty) {
          unawaited(loadHttpFallback());
        }
      },
    );

    yield* _notificationsController!.stream;
  }

  Uri _buildWebSocketUri(String token) {
    final apiUri = Uri.parse(Env.apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = apiUri.path.endsWith('/')
        ? apiUri.path.substring(0, apiUri.path.length - 1)
        : apiUri.path;

    return apiUri.replace(
      scheme: scheme,
      path: '$basePath/notifications/ws',
      queryParameters: {'token': token},
    );
  }

  Future<List<NotificationModel>> _fetchNotifications(String token) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final response = await dio.get('/notifications/me');
    final data = response.data;
    if (data is! List) {
      throw Exception('Format de réponse /notifications/me invalide: $data');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _notificationsController?.close();
    _notificationsController = null;
  }
}

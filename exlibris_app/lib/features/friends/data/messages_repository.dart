import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/pgp_service.dart';

class ChatMessage {
  final int idMessage;
  final int expediteurId;
  final int destinataireId;
  final String contenu;
  final DateTime dateEnvoi;

  ChatMessage({
    required this.idMessage,
    required this.expediteurId,
    required this.destinataireId,
    required this.contenu,
    required this.dateEnvoi,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      idMessage: json['id_message'] as int,
      expediteurId: json['expediteur_id'] as int,
      destinataireId: json['destinataire_id'] as int,
      contenu: json['contenu'] as String,
      dateEnvoi: DateTime.parse(json['date_envoi'] as String).toLocal(),
    );
  }

  ChatMessage copyWith({String? contenu}) {
    return ChatMessage(
      idMessage: idMessage,
      expediteurId: expediteurId,
      destinataireId: destinataireId,
      contenu: contenu ?? this.contenu,
      dateEnvoi: dateEnvoi,
    );
  }
}

class MessagesRepository {
  final Dio _dio;
  final PgpService _pgpService;

  MessagesRepository(this._dio, this._pgpService);

  Future<List<ChatMessage>> getMessages(int friendId) async {
    final res = await _dio.get('/messages/$friendId');
    final data = res.data as List;
    final messages = data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
        
    final decryptedMessages = <ChatMessage>[];
    for (final m in messages) {
       try {
           final decrypted = await _pgpService.decryptMessage(m.contenu);
           decryptedMessages.add(m.copyWith(contenu: decrypted));
       } catch(e) {
           decryptedMessages.add(m.copyWith(contenu: '🔒 Message illisible'));
       }
    }
    return decryptedMessages;
  }

  Future<ChatMessage> sendMessage(int friendId, String clearText, String friendPublicKey) async {
    final myPublicKey = await _pgpService.getPublicKeyLocal();
    if (myPublicKey == null) {
      throw Exception("Clé publique locale introuvable");
    }
    
    final cipherText = await _pgpService.encryptMessage(clearText, friendPublicKey, myPublicKey);
    
    final res = await _dio.post(
      '/messages/$friendId',
      data: {'contenu': cipherText},
    );
    final sentMessage = ChatMessage.fromJson(res.data as Map<String, dynamic>);
    return sentMessage.copyWith(contenu: clearText);
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final pgp = ref.watch(pgpServiceProvider);
  return MessagesRepository(dio, pgp);
});

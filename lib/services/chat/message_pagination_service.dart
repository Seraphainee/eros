/// `MessagePaginationService` — paginação por cursor do histórico.
///
/// Carrega mensagens "mais antigas que X" em chunks fixos. Usado
/// pela `TextChannelScreen` ao rolar para o topo.
///
/// Coleção: `messages/{messageId}`. Query: `channelId == X AND
/// createdAt < Y` ordenado desc, limit 50.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../models/message_model.dart';
import 'message_service.dart';

class MessagePaginationService {
  MessagePaginationService({
    FirebaseFirestore? firestore,
    MessageService? messageService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messageService = messageService ?? MessageService();

  final FirebaseFirestore _firestore;
  // Mantido para consistência de injeção; a paginação usa Firestore
  // diretamente para suportar cursores (streams de snapshot do
  // MessageService não aceitam `endBefore`).
  // ignore: unused_field
  final MessageService _messageService;

  static const int _pageSize = 50;

  /// Carrega a página de mensagens mais antigas que [before].
  /// Retorna a lista (desc) e o cursor para a próxima página.
  Future<({List<MessageModel> messages, DateTime? nextCursor})>
      loadOlderPage({
    required String channelId,
    DateTime? before,
  }) async {
    try {
      var query = _firestore
          .collection('messages')
          .where('channelId', isEqualTo: channelId)
          .where('deletedAt', isNull: true)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (before != null) {
        query = query.where('createdAt', isLessThan: before.toIso8601String());
      }
      final snap = await query.get();
      final messages = snap.docs
          .map((d) => MessageModel.fromJson(d.data()))
          .toList(growable: false);
      // Cursor = createdAt da mais antiga (último da lista desc).
      // Se veio menos que o pageSize, não há mais páginas.
      final nextCursor =
          messages.length == _pageSize ? messages.last.createdAt : null;
      return (messages: messages, nextCursor: nextCursor);
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }
}

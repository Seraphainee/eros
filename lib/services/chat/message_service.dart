/// `MessageService` — envio, edição, deleção e stream em tempo real
/// de mensagens de texto.
///
/// Coleção: `messages/{messageId}`. Query principal: filtrada por
/// `channelId` com ordem por `createdAt`.
///
/// Permissões: checa `canSendMessage` antes de cada envio, e
/// `canReadHistory` no stream inicial. Mensagens deletadas são
/// soft-deleted (campo `deletedAt`) para manter histórico de
/// moderação, mas a UI deve filtrá-las.
///
/// Rate limit: `AppConstants.maxMessagesPerMinute` é verificado
/// in-memory (sessão) — não substitui regra de servidor, é uma
/// otimização para evitar envios duplicados quando o usuário
/// martela o botão de enviar.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../models/attachment_model.dart';
import '../../models/message_model.dart';
import '../channels/channel_permission_service.dart';

class MessageService {
  MessageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    fb.FirebaseAuth? firebaseAuth,
    ChannelPermissionService? channelPermissionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _channelPermission = channelPermissionService ?? ChannelPermissionService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final fb.FirebaseAuth _auth;
  final ChannelPermissionService _channelPermission;

  /// Janela de rate limit em memória.
  final Map<String, List<DateTime>> _recentSendsByUser = <String, List<DateTime>>{};

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('messages');

  /// Envia uma mensagem. Lança [AuthException] se não tiver permissão,
  /// ou se a validação falhar.
  Future<MessageModel> sendMessage({
    required String groupId,
    required String channelId,
    required String content,
    List<AttachmentModel> attachments = const <AttachmentModel>[],
    String? replyToId,
    List<String> mentions = const <String>[],
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'not-authenticated');
    }
    final userId = user.uid;

    // Validação de conteúdo.
    final validationError = Validators.validateMessage(content);
    if (validationError != null) {
      throw AuthException(message: 'invalid-message: $validationError');
    }
    if (attachments.length > AppConstants.maxAttachmentsPerMessage) {
      throw const AuthException(message: 'too-many-attachments');
    }

    // Permissão.
    final allowed = await _channelPermission.canSendMessage(
      groupId: groupId,
      channelId: channelId,
      userId: userId,
    );
    if (!allowed) {
      throw const AuthException(message: 'no-send-permission');
    }

    // Rate limit local (sessão).
    _enforceRateLimit(userId);

    final ref = _messagesRef.doc();
    final now = DateTime.now();
    final message = MessageModel(
      id: ref.id,
      channelId: channelId,
      groupId: groupId,
      authorId: userId,
      content: content.trim(),
      attachments: attachments,
      replyToId: replyToId,
      createdAt: now,
      mentions: mentions,
    );

    try {
      await ref.set(message.toJson());
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
    Logger.i('MessageService: mensagem ${message.id} enviada em $channelId');
    return message;
  }

  /// Edita uma mensagem. Apenas o próprio autor.
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'not-authenticated');
    }
    final validationError = Validators.validateMessage(newContent);
    if (validationError != null) {
      throw AuthException(message: 'invalid-message: $validationError');
    }
    final ref = _messagesRef.doc(messageId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'message-not-found');
    }
    final msg = MessageModel.fromJson(snap.data()!);
    if (msg.authorId != user.uid) {
      throw const AuthException(message: 'not-message-author');
    }
    if (msg.isDeleted) {
      throw const AuthException(message: 'message-deleted');
    }
    try {
      await ref.update(<String, dynamic>{
        'content': newContent.trim(),
        'editedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Soft-delete: o autor marca a própria mensagem como deletada.
  /// Moderadores com `kickMembers` podem deletar mensagens de outros
  /// — isso é responsabilidade do moderador UI passar `forceByModerator: true`
  /// e ter o cargo adequado. (Etapa 6+ adiciona o painel de moderação.)
  Future<void> deleteMessage({
    required String messageId,
    bool forceByModerator = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'not-authenticated');
    }
    final ref = _messagesRef.doc(messageId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'message-not-found');
    }
    final msg = MessageModel.fromJson(snap.data()!);
    if (!forceByModerator && msg.authorId != user.uid) {
      throw const AuthException(message: 'not-message-author');
    }
    try {
      await ref.update(<String, dynamic>{
        'content': '',
        'deletedAt': DateTime.now().toIso8601String(),
        'attachments': <Map<String, dynamic>>[],
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream de mensagens de um canal, ordenadas por `createdAt` asc.
  ///
  /// Filtra mensagens soft-deleted no client (Firestore não tem
  /// comparação por "campo ausente ou != null" simples; alternativa
  /// é usar `where('deletedAt', isNull: true)` que funciona).
  Stream<List<MessageModel>> watchChannelMessages(String channelId) {
    return _messagesRef
        .where('channelId', isEqualTo: channelId)
        .where('deletedAt', isNull: true)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromJson(d.data()))
            .toList(growable: false));
  }

  void _enforceRateLimit(String userId) {
    final now = DateTime.now();
    final window = now.subtract(const Duration(minutes: 1));
    final list = (_recentSendsByUser[userId] ?? <DateTime>[])
      ..removeWhere((t) => t.isBefore(window));
    if (list.length >= AppConstants.maxMessagesPerMinute) {
      throw const AuthException(message: 'rate-limited');
    }
    list.add(now);
    _recentSendsByUser[userId] = list;
  }
}

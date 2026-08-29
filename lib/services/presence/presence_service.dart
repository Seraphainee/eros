/// `PresenceService` — presença de usuários em canais de voz.
///
/// Grava em `presence/{userId}` o canal de voz em que o usuário está
/// (ou `null` se não está em nenhum). Usado pela tela do servidor
/// para mostrar "N Online" no card do grupo e a contagem de pessoas
/// ao lado de cada canal, mesmo para quem não está na chamada.
///
/// Implementação manual (Map<String,dynamic>) — não usa o
/// `PresenceModel` (freezed) porque os arquivos gerados
/// (`.freezed.dart`/`.g.dart`) ainda não foram criados via
/// `build_runner` neste projeto; quando forem gerados, este service
/// pode ser migrado para usar o model tipado.
///
/// `lastSeen` permite considerar o registro "expirado" (usuário
/// fechou o app sem avisar) mesmo sem um processo de limpeza no
/// servidor — a UI simplesmente ignora presenças com `lastSeen`
/// mais antigo que [_staleAfter].
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _presenceRef =>
      _firestore.collection('presence');

  /// Considera "offline" qualquer presença sem heartbeat há mais
  /// tempo que isto (usuário provavelmente perdeu conexão/fechou o
  /// app sem chamar [leaveVoiceChannel]).
  static const Duration staleAfter = Duration(seconds: 45);

  /// Marca [userId] como presente no canal de voz [channelId] do
  /// grupo [groupId]. Chamar de novo (heartbeat) atualiza `lastSeen`.
  Future<void> joinVoiceChannel({
    required String userId,
    required String groupId,
    required String channelId,
  }) async {
    try {
      await _presenceRef.doc(userId).set(<String, dynamic>{
        'userId': userId,
        'groupId': groupId,
        'voiceChannelId': channelId,
        'state': 'inRoom',
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Remove a presença de voz de [userId] (usuário saiu do canal).
  Future<void> leaveVoiceChannel(String userId) async {
    try {
      await _presenceRef.doc(userId).set(<String, dynamic>{
        'userId': userId,
        'voiceChannelId': null,
        'state': 'online',
        'lastSeen': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Heartbeat periódico para manter `lastSeen` fresco enquanto o
  /// usuário permanece no canal (chamar a cada ~20s de um Timer no
  /// controller da sala de voz).
  Future<void> heartbeat(String userId) async {
    try {
      await _presenceRef.doc(userId).update(<String, dynamic>{
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } on FirebaseException {
      // Heartbeat silencioso: se o doc não existe mais, o próximo
      // joinVoiceChannel recria. Não interrompe a UI por isso.
    }
  }

  /// Stream de todos os `userId` atualmente presentes (não-stale) em
  /// [channelId]. Usado para o contador "N" ao lado do canal e para
  /// os avatares de quem está na chamada.
  Stream<List<String>> watchChannelPresence(String channelId) {
    return _presenceRef
        .where('voiceChannelId', isEqualTo: channelId)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().subtract(staleAfter);
      return snap.docs.where((doc) {
        final lastSeenStr = doc.data()['lastSeen'] as String?;
        if (lastSeenStr == null) return false;
        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) return false;
        return lastSeen.isAfter(cutoff);
      }).map((doc) => doc.id).toList();
    }).handleError((error, st) {
      throw FirestoreException(message: error.toString(), stackTrace: st);
    });
  }

  /// Stream de quantos membros de [groupId] estão online (em
  /// qualquer canal de voz do grupo OU com `state == online`).
  /// Usado no badge "N Online" do card do servidor.
  Stream<int> watchGroupOnlineCount(String groupId) {
    return _presenceRef
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().subtract(staleAfter);
      return snap.docs.where((doc) {
        final lastSeenStr = doc.data()['lastSeen'] as String?;
        if (lastSeenStr == null) return false;
        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) return false;
        return lastSeen.isAfter(cutoff);
      }).length;
    }).handleError((error, st) {
      throw FirestoreException(message: error.toString(), stackTrace: st);
    });
  }
}
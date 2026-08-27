/// `ChannelPermissionService` — fachada de permissões para features
/// (chat de texto, voz).
///
/// Encapsula o ciclo:
///   1. Resolver o `GroupModel.ownerId`.
///   2. Delegar ao `PermissionResolver` a conta do bitmask
///      (cargo + override de canal).
///   3. Expor métodos `canX` que a UI/feature chama.
///
/// O chat (Etapa 3) e a sala de voz (Etapa 4) devem usar esta classe
/// em vez de injetar Firestore diretamente.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../models/channel_model.dart';
import '../permissions/permission_resolver.dart';

class ChannelPermissionService {
  ChannelPermissionService({
    FirebaseFirestore? firestore,
    PermissionResolver? permissionResolver,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _resolver = permissionResolver ?? PermissionResolver();

  final FirebaseFirestore _firestore;
  final PermissionResolver _resolver;

  /// Permissão para enviar mensagem em um canal de texto.
  Future<bool> canSendMessage({
    required String groupId,
    required String channelId,
    required String userId,
  }) async {
    final channel = await _loadChannel(channelId);
    if (!channel.isText) return false;
    final resolved = await _resolve(groupId, channel, userId);
    return resolved.can(_sendMessages);
  }

  /// Permissão para ler histórico de mensagens.
  Future<bool> canReadHistory({
    required String groupId,
    required String channelId,
    required String userId,
  }) async {
    final channel = await _loadChannel(channelId);
    final resolved = await _resolve(groupId, channel, userId);
    return resolved.can(_readHistory);
  }

  /// Permissão para gerenciar canais do grupo (criar/renomear/etc).
  /// Não depende de canal específico.
  Future<bool> canManageChannels({
    required String groupId,
    required String userId,
  }) async {
    final ownerId = await _ownerId(groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: groupId,
      userId: userId,
      groupOwnerId: ownerId,
    );
    return resolved.can(_manageChannels);
  }

  /// Permissão para falar em um canal de voz.
  Future<bool> canSpeakInVoice({
    required String groupId,
    required String channelId,
    required String userId,
  }) async {
    final channel = await _loadChannel(channelId);
    if (!channel.isVoice) return false;
    final resolved = await _resolve(groupId, channel, userId);
    return resolved.can(_speakInVoice);
  }

  /// Permissão para silenciar outros membros em um canal de voz.
  Future<bool> canMuteMembers({
    required String groupId,
    required String channelId,
    required String userId,
  }) async {
    final channel = await _loadChannel(channelId);
    final resolved = await _resolve(groupId, channel, userId);
    return resolved.can(_muteMembers);
  }

  // --- helpers ---

  Future<ChannelModel> _loadChannel(String channelId) async {
    final snap =
        await _firestore.collection('channels').doc(channelId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'channel-not-found');
    }
    return ChannelModel.fromJson(<String, dynamic>{
      ...snap.data()!,
      'id': snap.id,
    });
  }

  Future<ResolvedPermissions> _resolve(
    String groupId,
    ChannelModel channel,
    String userId,
  ) async {
    final ownerId = await _ownerId(groupId);
    return _resolver.resolveForChannel(
      groupId: groupId,
      channelId: channel.id,
      userId: userId,
      groupOwnerId: ownerId,
      channelPermissionOverrides: channel.permissionOverrides,
    );
  }

  Future<String> _ownerId(String groupId) async {
    final snap = await _firestore.collection('groups').doc(groupId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'group-not-found');
    }
    return snap.data()!['ownerId'] as String;
  }
}

// Bits espelhados.
const int _manageChannels = 1 << 0;
const int _muteMembers = 1 << 3;
const int _speakInVoice = 1 << 4;
const int _sendMessages = 1 << 5;
const int _readHistory = 1 << 6;

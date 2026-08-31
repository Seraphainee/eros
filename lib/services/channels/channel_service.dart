/// `ChannelService` — CRUD de canais (texto e voz).
///
/// Coleção: `channels/{channelId}` (raiz, não aninhada no grupo).
/// Índice composto: `groupId + order` para queries "canais do grupo
/// ordenados".
///
/// Regras:
/// - Apenas quem tem `manageChannels` cria/renomeia/deleta/reordena/
///   define senha.
/// - Não permite deletar o último canal do grupo.
/// - `name` é normalizado para minúsculas e sem espaços nas pontas.
/// - Senha de canal nunca é armazenada em texto puro — apenas o hash
///   SHA-256 fica no documento (que é legível por qualquer membro,
///   já que o nome/lista de presença do canal ficam visíveis mesmo
///   sem acesso). Ver `ChannelModel.passwordHash`.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../models/channel_model.dart';
import '../permissions/permission_resolver.dart';

class ChannelService {
  ChannelService({
    FirebaseFirestore? firestore,
    PermissionResolver? permissionResolver,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _resolver = permissionResolver ?? PermissionResolver();

  final FirebaseFirestore _firestore;
  final PermissionResolver _resolver;

  CollectionReference<Map<String, dynamic>> get _channelsRef =>
      _firestore.collection('channels');

  /// Hash SHA-256 de uma senha em texto puro, em hexadecimal.
  static String hashPassword(String plainPassword) {
    return sha256.convert(utf8.encode(plainPassword)).toString();
  }

  /// Cria um canal. Atribui `order` = max(order)+1. Se [password]
  /// for informada, o canal nasce protegido (hash salvo, nunca a
  /// senha em si).
  Future<ChannelModel> createChannel({
    required String groupId,
    required String name,
    required ChannelType type,
    required String actingUserId,
    VoiceMode voiceMode = VoiceMode.free,
    ChannelVisibility visibility = ChannelVisibility.public,
    String? password,
  }) async {
    final cleaned = name.trim().toLowerCase();
    if (cleaned.isEmpty) {
      throw const AuthException(message: 'invalid-channel-name');
    }
    final ownerId = await _requireOwnerId(groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageChannels)) {
      throw const AuthException(message: 'no-manage-channels-permission');
    }
    // Unicidade por (groupId, name).
    final existing = await _channelsRef
        .where('groupId', isEqualTo: groupId)
        .where('name', isEqualTo: cleaned)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const AuthException(message: 'channel-name-taken');
    }
    // order = max + 1
    final all = await _channelsRef
        .where('groupId', isEqualTo: groupId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder = all.docs.isEmpty
        ? 0
        : ((all.docs.first.data()['order'] as num).toInt() + 1);

    final trimmedPassword = password?.trim();
    final passwordHash = (trimmedPassword != null && trimmedPassword.isNotEmpty)
        ? hashPassword(trimmedPassword)
        : null;

    final ref = _channelsRef.doc();
    final channel = ChannelModel(
      id: ref.id,
      groupId: groupId,
      name: cleaned,
      type: type,
      order: nextOrder,
      permissionOverrides: 0,
      voiceMode: voiceMode,
      visibility: visibility,
      passwordHash: passwordHash,
      createdAt: DateTime.now(),
    );
    try {
      await ref.set(channel.toJson());
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
    Logger.i('ChannelService: canal ${channel.id} ($cleaned) criado em $groupId');
    return channel;
  }

  /// Define, troca ou remove a senha do canal. Passe `null` ou
  /// string vazia em [password] para remover a proteção.
  /// Só quem tem `manageChannels` pode chamar.
  Future<void> setChannelPassword({
    required String channelId,
    required String? password,
    required String actingUserId,
  }) async {
    final snap = await _channelsRef.doc(channelId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'channel-not-found');
    }
    final channel = ChannelModel.fromJson(snap.data()!);
    final ownerId = await _requireOwnerId(channel.groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: channel.groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageChannels)) {
      throw const AuthException(message: 'no-manage-channels-permission');
    }
    final trimmed = password?.trim();
    final newHash =
        (trimmed != null && trimmed.isNotEmpty) ? hashPassword(trimmed) : null;
    try {
      await _channelsRef.doc(channelId).update(<String, dynamic>{
        'passwordHash': newHash,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Verifica se [password] confere com a senha do canal.
  ///
  /// Retorna `true` se o canal NÃO tem senha (entrada livre) OU se
  /// o hash bate. Retorna `false` apenas quando o canal tem senha e
  /// ela não confere. Não usa Firestore para a checagem em si —
  /// compara localmente contra o `ChannelModel` já carregado, então
  /// o chamador deve passar o [channel] atualizado (ex: vindo do
  /// `channelsStreamProvider`).
  bool verifyPassword(ChannelModel channel, String password) {
    if (!channel.isPasswordProtected) return true;
    return hashPassword(password.trim()) == channel.passwordHash;
  }

  /// Deleta um canal. Recusa se for o último.
  Future<void> deleteChannel({
    required String channelId,
    required String actingUserId,
  }) async {
    final snap = await _channelsRef.doc(channelId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'channel-not-found');
    }
    final channel = ChannelModel.fromJson(snap.data()!);
    final ownerId = await _requireOwnerId(channel.groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: channel.groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageChannels)) {
      throw const AuthException(message: 'no-manage-channels-permission');
    }
    // Não permite deletar o último canal.
    final others = await _channelsRef
        .where('groupId', isEqualTo: channel.groupId)
        .get();
    if (others.docs.length <= 1) {
      throw const AuthException(message: 'cannot-delete-last-channel');
    }
    try {
      await _channelsRef.doc(channelId).delete();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Renomeia.
  Future<void> renameChannel({
    required String channelId,
    required String newName,
    required String actingUserId,
  }) async {
    final cleaned = newName.trim().toLowerCase();
    if (cleaned.isEmpty) {
      throw const AuthException(message: 'invalid-channel-name');
    }
    final snap = await _channelsRef.doc(channelId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'channel-not-found');
    }
    final channel = ChannelModel.fromJson(snap.data()!);
    final ownerId = await _requireOwnerId(channel.groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: channel.groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageChannels)) {
      throw const AuthException(message: 'no-manage-channels-permission');
    }
    // Unicidade.
    final dup = await _channelsRef
        .where('groupId', isEqualTo: channel.groupId)
        .where('name', isEqualTo: cleaned)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty && dup.docs.first.id != channelId) {
      throw const AuthException(message: 'channel-name-taken');
    }
    try {
      await _channelsRef.doc(channelId).update(<String, dynamic>{
        'name': cleaned,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Aplica override de permissão ao canal (ALLOW only — OR).
  Future<void> setChannelPermissionOverride({
    required String channelId,
    required int allow,
    required String actingUserId,
  }) async {
    final snap = await _channelsRef.doc(channelId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'channel-not-found');
    }
    final channel = ChannelModel.fromJson(snap.data()!);
    final ownerId = await _requireOwnerId(channel.groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: channel.groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageRoles)) {
      throw const AuthException(message: 'no-manage-roles-permission');
    }
    // Validação: bits de permissão válidos.
    final validMask = _allPermissionMask;
    if ((allow & ~validMask) != 0) {
      throw const AuthException(message: 'invalid-permission-bits');
    }
    try {
      await _channelsRef.doc(channelId).update(<String, dynamic>{
        'permissionOverrides': allow,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Reordena canais: aplica `order` na sequência fornecida.
  /// `orderedIds[0]` => order 0, e assim por diante.
  Future<void> reorderChannels({
    required String groupId,
    required List<String> orderedIds,
    required String actingUserId,
  }) async {
    final ownerId = await _requireOwnerId(groupId);
    final resolved = await _resolver.resolveForGroup(
      groupId: groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_manageChannels)) {
      throw const AuthException(message: 'no-manage-channels-permission');
    }
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_channelsRef.doc(orderedIds[i]), <String, dynamic>{
        'order': i,
      });
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream de canais de um grupo, ordenados.
  Stream<List<ChannelModel>> watchChannels(String groupId) {
    return _channelsRef
        .where('groupId', isEqualTo: groupId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChannelModel.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }))
            .toList(growable: false));
  }

  Future<String> _requireOwnerId(String groupId) async {
    final snap = await _firestore.collection('groups').doc(groupId).get();
    if (!snap.exists || snap.data() == null) {
      throw const FirestoreException(message: 'group-not-found');
    }
    return snap.data()!['ownerId'] as String;
  }
}

// Permissões espelhadas para evitar import circular.
const int _manageChannels = 1 << 0;
const int _manageRoles = 1 << 1;
const int _allPermissionMask = (1 << 8) - 1; // 8 bits
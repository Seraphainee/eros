/// `GroupService` — CRUD de grupos.
///
/// Responsabilidades:
/// - Criar grupo (com ID numérico único, cargos Owner/Member default,
///   canal #general, membership do owner).
/// - Ler/observar grupo e listar grupos do usuário.
/// - Buscar grupo por ID numérico (ex: "#2800").
/// - Atualizar ícone (apenas owner).
/// - Deletar grupo (apenas owner).
///
/// Coleções tocadas:
/// - `groups/{groupId}`
/// - `groups/{groupId}/roles/{roleId}` (subcoleção de cargos)
/// - `memberships/{groupId}_{userId}`
/// - `channels/{channelId}` (canal #general)
/// - `counters/groups` (contador atômico do numericId)
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../models/channel_model.dart';
import '../../models/group_model.dart';
import '../../models/member_model.dart';
import '../../models/permission_model.dart';
import '../../models/role_model.dart';
import '../permissions/permission_resolver.dart';

class GroupService {
  GroupService({
    FirebaseFirestore? firestore,
    PermissionResolver? permissionResolver,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _resolver = permissionResolver ?? PermissionResolver();

  final FirebaseFirestore _firestore;
  final PermissionResolver _resolver;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('groups');

  /// Contador global que gera o próximo `numericId` de grupo.
  /// Documento único `counters/groups` com campo `value` (int).
  DocumentReference<Map<String, dynamic>> get _groupCounterRef =>
      _firestore.collection('counters').doc('groups');

  /// Ponto de partida dos IDs — evita números "curtos demais"
  /// (mesmo espírito do `#2800` visto na referência RaidCall).
  static const int _numericIdStart = 1000;

  /// Gera o próximo `numericId` de forma atômica via transação.
  ///
  /// Se `counters/groups` não existir ainda, começa em
  /// `_numericIdStart`. Caso contrário, incrementa `value` em 1 e
  /// retorna o novo valor. A transação garante que duas criações
  /// simultâneas nunca recebam o mesmo número.
  Future<int> _nextNumericId() {
    return _firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(_groupCounterRef);
      final current = (snap.data()?['value'] as int?) ?? (_numericIdStart - 1);
      final next = current + 1;
      tx.set(_groupCounterRef, <String, dynamic>{'value': next});
      return next;
    });
  }

  /// Cria um grupo, cargos Owner/Member, membership do owner e
  /// canal #general. O `numericId` é reservado atomicamente ANTES
  /// do batch (transação separada, pois `runTransaction` e `batch`
  /// não podem ser combinados no mesmo commit).
  Future<GroupModel> createGroup({
    required String name,
    required String ownerId,
    String? iconUrl,
  }) async {
    final validationError = Validators.validateGroupName(name);
    if (validationError != null) {
      throw AuthException(message: 'invalid-group-name: $validationError');
    }
    if (ownerId.isEmpty) {
      throw const AuthException(message: 'missing-owner-id');
    }

    // Reserva o ID numérico único antes de criar o resto — se algo
    // falhar depois, o número fica "queimado" (não reutilizado),
    // igual ao comportamento padrão de contadores sequenciais.
    final int numericId;
    try {
      numericId = await _nextNumericId();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }

    final groupRef = _groupsRef.doc();
    final groupId = groupRef.id;
    final now = DateTime.now();

    final ownerRoleRef = groupRef.collection('roles').doc('owner');
    final memberRoleRef = groupRef.collection('roles').doc('member');
    final generalChannelRef = _firestore.collection('channels').doc();
    final membershipRef =
        _firestore.collection('memberships').doc('${groupId}_$ownerId');

    final batch = _firestore.batch();
    batch.set(groupRef, <String, dynamic>{
      'id': groupId,
      'numericId': numericId,
      'name': name,
      'ownerId': ownerId,
      'iconUrl': iconUrl,
      'createdAt': now.toIso8601String(),
      'memberCount': 1,
    });
    batch.set(ownerRoleRef, <String, dynamic>{
      'id': 'owner',
      'groupId': groupId,
      'name': 'Owner',
      'permissionsBitmask': PermissionKeys.allBits,
      'createdAt': now.toIso8601String(),
    });
    batch.set(memberRoleRef, <String, dynamic>{
      'id': 'member',
      'groupId': groupId,
      'name': 'Member',
      'permissionsBitmask': PermissionKeys.defaultMemberBits,
      'createdAt': now.toIso8601String(),
    });
    batch.set(membershipRef, <String, dynamic>{
      'groupId': groupId,
      'userId': ownerId,
      'roleId': 'owner',
      'joinedAt': now.toIso8601String(),
    });
    batch.set(generalChannelRef, <String, dynamic>{
      'id': generalChannelRef.id,
      'groupId': groupId,
      'name': 'general',
      'type': ChannelType.text.name,
      'order': 0,
      'permissionOverrides': 0,
      'createdAt': now.toIso8601String(),
    });

    try {
      await batch.commit();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }

    Logger.i('GroupService: grupo criado $groupId (#$numericId) por $ownerId');
    return GroupModel(
      id: groupId,
      numericId: numericId,
      name: name,
      ownerId: ownerId,
      iconUrl: iconUrl,
      createdAt: now,
      memberCount: 1,
    );
  }

  /// Stream de um grupo.
  Stream<GroupModel?> watchGroup(String groupId) {
    return _groupsRef.doc(groupId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return GroupModel.fromJson(<String, dynamic>{
        ...snap.data()!,
        'id': snap.id,
      });
    });
  }

  /// Busca um grupo pelo `numericId` (ex: usuário digitou "2800" na
  /// busca ou colou um link `.../join?sid=2800`). Retorna `null` se
  /// não encontrado. Usa `limit(1)` pois `numericId` é único.
  Future<GroupModel?> findByNumericId(int numericId) async {
    try {
      final snap = await _groupsRef
          .where('numericId', isEqualTo: numericId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return GroupModel.fromJson(<String, dynamic>{
        ...doc.data(),
        'id': doc.id,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream da lista de grupos em que o usuário é membro.
  ///
  /// Implementação: escuta `memberships where userId == uid`,
  /// e para cada membership carrega o grupo. Combinações são
  /// feitas em memória; o índice composto `userId + groupId`
  /// (declarado no plano) é o que torna a query barata.
  Stream<List<GroupModel>> watchUserGroups(String userId) {
    return _firestore
        .collection('memberships')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <GroupModel>[];
      final groupIds = snap.docs
          .map((d) => d.data()['groupId'] as String)
          .toList();
      // Firestore `in` query aceita até 30 itens por query.
      if (groupIds.length <= 30) {
        final groups = await _groupsRef
            .where(FieldPath.documentId, whereIn: groupIds)
            .get();
        return groups.docs
            .map((d) => GroupModel.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }))
            .toList();
      }
      // Fallback: batch em chunks de 30.
      final results = <GroupModel>[];
      for (var i = 0; i < groupIds.length; i += 30) {
        final chunk = groupIds.sublist(
          i,
          (i + 30).clamp(0, groupIds.length),
        );
        final groups = await _groupsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(groups.docs
            .map((d) => GroupModel.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                })));
      }
      return results;
    }).handleError((error, st) {
      throw FirestoreException(message: error.toString(), stackTrace: st);
    });
  }

  /// Atualiza o ícone do grupo. Apenas o owner pode.
  Future<void> updateGroupIcon({
    required String groupId,
    required String iconUrl,
    required String actingUserId,
  }) async {
    await _assertOwner(groupId: groupId, actingUserId: actingUserId);
    try {
      await _groupsRef.doc(groupId).update(<String, dynamic>{
        'iconUrl': iconUrl,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Deleta um grupo. Apenas o owner pode. Não apaga memberships
  /// automaticamente — a UI deve limpar com `MembershipService`
  /// em sequência (a Etapa 3 trata).
  Future<void> deleteGroup({
    required String groupId,
    required String actingUserId,
  }) async {
    await _assertOwner(groupId: groupId, actingUserId: actingUserId);
    try {
      await _groupsRef.doc(groupId).delete();
      // Limpa roles (subcoleção).
      final roles = await _groupsRef.doc(groupId).collection('roles').get();
      final batch = _firestore.batch();
      for (final r in roles.docs) {
        batch.delete(r.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  Future<void> _assertOwner({
    required String groupId,
    required String actingUserId,
  }) async {
    final group = await _groupsRef.doc(groupId).get();
    if (!group.exists || group.data() == null) {
      throw const FirestoreException(message: 'group-not-found');
    }
    final ownerId = group.data()!['ownerId'] as String;
    if (ownerId != actingUserId) {
      throw const AuthException(message: 'not-owner');
    }
  }
}
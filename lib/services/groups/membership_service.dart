/// `MembershipService` — gerencia membros de um grupo.
///
/// Responsabilidades:
/// - Adicionar membro (com cargo).
/// - Remover membro (com checagem de permissão + proteção do owner).
/// - Trocar cargo de um membro (com checagem de escalonamento).
/// - Observar membros de um grupo / minha membership.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/member_model.dart';
import '../permissions/permission_resolver.dart';

class MembershipService {
  MembershipService({
    FirebaseFirestore? firestore,
    PermissionResolver? permissionResolver,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _resolver = permissionResolver ?? PermissionResolver();

  final FirebaseFirestore _firestore;
  final PermissionResolver _resolver;

  /// Adiciona um membro com um cargo específico.
  ///
  /// Quem chama deve ter `manageInvites` ou ser o owner.
  Future<void> addMember({
    required String groupId,
    required String userId,
    required String roleId,
    required String actingUserId,
  }) async {
    await _assertCanManageMembers(
      groupId: groupId,
      actingUserId: actingUserId,
    );
    final ref = _firestore
        .collection('memberships')
        .doc(MemberModel(groupId: groupId, userId: userId, roleId: roleId, joinedAt: DateTime.now()).docId);
    if ((await ref.get()).exists) {
      // Já é membro — não é erro, idempotente.
      return;
    }
    try {
      await ref.set(<String, dynamic>{
        'groupId': groupId,
        'userId': userId,
        'roleId': roleId,
        'joinedAt': DateTime.now().toIso8601String(),
      });
      await _firestore
          .collection('groups')
          .doc(groupId)
          .update(<String, dynamic>{
        'memberCount': FieldValue.increment(1),
      });
      _resolver.invalidateMember(groupId, userId);
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Remove um membro. Não remove o owner.
  Future<void> removeMember({
    required String groupId,
    required String userId,
    required String actingUserId,
  }) async {
    await _assertCanManageMembers(
      groupId: groupId,
      actingUserId: actingUserId,
    );
    final groupSnap = await _firestore.collection('groups').doc(groupId).get();
    if (!groupSnap.exists) {
      throw const FirestoreException(message: 'group-not-found');
    }
    if ((groupSnap.data()!['ownerId'] as String) == userId) {
      throw const AuthException(message: 'cannot-remove-owner');
    }
    final memberDocId = '${groupId}_$userId';
    final ref = _firestore.collection('memberships').doc(memberDocId);
    if (!(await ref.get()).exists) {
      return;
    }
    try {
      await ref.delete();
      await _firestore
          .collection('groups')
          .doc(groupId)
          .update(<String, dynamic>{
        'memberCount': FieldValue.increment(-1),
      });
      _resolver.invalidateMember(groupId, userId);
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Troca o cargo de um membro.
  ///
  /// Aplica a regra de segurança do plano (seção 5):
  /// "admin não se autopromove" — o autor não pode atribuir bits
  /// que ele mesmo não tem.
  Future<void> changeMemberRole({
    required String groupId,
    required String userId,
    required String newRoleId,
    required String actingUserId,
  }) async {
    final actingResolved = await _resolver.resolveForGroup(
      groupId: groupId,
      userId: actingUserId,
      groupOwnerId: (await _firestore.collection('groups').doc(groupId).get())
              .data()?['ownerId'] as String? ??
          '',
    );
    if (!actingResolved.can(_permissionManageRoles)) {
      throw const AuthException(message: 'no-manage-roles-permission');
    }
    final targetRole = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roles')
        .doc(newRoleId)
        .get();
    if (!targetRole.exists) {
      throw const FirestoreException(message: 'role-not-found');
    }
    final targetBitmask =
        (targetRole.data()!['permissionsBitmask'] as num).toInt();
    _resolver.assertNoPrivilegeEscalation(
      actingUserBitmask: actingResolved.effectiveBitmask,
      targetBitmask: targetBitmask,
    );
    final memberDocId = '${groupId}_$userId';
    try {
      await _firestore
          .collection('memberships')
          .doc(memberDocId)
          .update(<String, dynamic>{'roleId': newRoleId});
      _resolver.invalidateMember(groupId, userId);
      _resolver.invalidateRole(groupId, newRoleId);
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream da membership de um usuário num grupo.
  Stream<MemberModel?> watchMyMembership({
    required String groupId,
    required String userId,
  }) {
    final id = '${groupId}_$userId';
    return _firestore
        .collection('memberships')
        .doc(id)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return MemberModel.fromJson(snap.data()!);
    });
  }

  /// Stream de todos os membros de um grupo.
  Stream<List<MemberModel>> watchMembers(String groupId) {
    return _firestore
        .collection('memberships')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MemberModel.fromJson(d.data()))
            .toList(growable: false));
  }

  /// Indica se o usuário é membro (snapshot one-shot).
  Future<MemberModel?> getMembership({
    required String groupId,
    required String userId,
  }) async {
    return _resolver.getMember(groupId: groupId, userId: userId);
  }

  // -- Permissões --

  Future<void> _assertCanManageMembers({
    required String groupId,
    required String actingUserId,
  }) async {
    final groupSnap = await _firestore.collection('groups').doc(groupId).get();
    if (!groupSnap.exists || groupSnap.data() == null) {
      throw const FirestoreException(message: 'group-not-found');
    }
    final ownerId = groupSnap.data()!['ownerId'] as String;
    if (ownerId == actingUserId) return; // owner sempre pode
    final resolved = await _resolver.resolveForGroup(
      groupId: groupId,
      userId: actingUserId,
      groupOwnerId: ownerId,
    );
    if (!resolved.can(_permissionManageInvites) &&
        !resolved.can(_permissionKickMembers)) {
      throw const AuthException(message: 'no-manage-members-permission');
    }
  }
}

// Para evitar importar PermissionKeys em todo lugar só por uma
// checagem local; mantemos as constantes espelhadas.
const int _permissionManageRoles = 1 << 1;
const int _permissionKickMembers = 1 << 2;
const int _permissionManageInvites = 1 << 7;

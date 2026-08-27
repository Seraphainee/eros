/// `PermissionResolver` — espelho local do esquema de permissões.
///
/// **Regra do plano (seção 5 e 7):**
/// "permission_resolver.dart é espelho local, não fonte da verdade."
/// Firestore Security Rules são a fonte da verdade. Esta classe
/// existe para:
/// 1. Evitar round-trips desnecessários ao backend quando o
///    `RoleModel` já está cacheado.
/// 2. Centralizar a lógica "override de canal > cargo > default"
///    usada por `MembershipService`/`ChannelPermissionService`.
/// 3. Bloquear ações de escalonamento de privilégio (admin não se
///    autopromove) antes de chegar ao Firestore.
///
/// Hierarquia (maior -> menor prioridade):
///   1. Owner do grupo (sempre tem `manageChannels`, `manageRoles`,
///      `kickMembers`, `muteMembers`, `manageInvites` — mesmo se o
///      bitmask do cargo Owner for editado).
///   2. Bitmask do cargo do usuário no grupo.
///   3. Override de canal (`ChannelModel.permissionOverrides`) — soma
///      de bits (ALLOW only).
///   4. Se não houver nenhum: 0.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/member_model.dart';
import '../../models/permission_model.dart';
import '../../models/role_model.dart';

/// Snapshot de permissões resolvidas para um usuário em um (grupo, canal).
class ResolvedPermissions {
  const ResolvedPermissions({
    required this.bitmask,
    required this.isOwner,
  });

  /// Bitmask final = cargo OR override de canal (se houver).
  final int bitmask;

  /// Verdadeiro se o usuário é o `ownerId` do grupo.
  final bool isOwner;

  /// Combinação final = bitmask OR (se owner, todos os bits de gestão).
  int get effectiveBitmask {
    if (!isOwner) return bitmask;
    return bitmask |
        PermissionKeys.manageChannels |
        PermissionKeys.manageRoles |
        PermissionKeys.kickMembers |
        PermissionKeys.muteMembers |
        PermissionKeys.manageInvites;
  }

  bool can(int permissionBit) =>
      (effectiveBitmask & permissionBit) != 0;
}

class PermissionResolver {
  PermissionResolver({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Cache simples: `roleId -> (bitmask, fetchedAt)`. TTL de 5 min —
  /// cargos raramente mudam, e quando mudam (Etapa 3) o serviço
  /// chama `invalidateRole`.
  final Map<String, _CachedBitmask> _roleCache = <String, _CachedBitmask>{};
  final Map<String, MemberModel> _memberCache = <String, MemberModel>{};

  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Doc de membership: `memberships/{groupId}_{userId}`.
  String _membershipDocId(String groupId, String userId) =>
      '${groupId}_$userId';

  /// Busca o `MemberModel` (com cache).
  Future<MemberModel?> getMember({
    required String groupId,
    required String userId,
    bool forceRefresh = false,
  }) async {
    final id = _membershipDocId(groupId, userId);
    if (!forceRefresh) {
      final cached = _memberCache[id];
      if (cached != null) return cached;
    }
    final snap = await _firestore.collection('memberships').doc(id).get();
    if (!snap.exists || snap.data() == null) {
      _memberCache.remove(id);
      return null;
    }
    final member = MemberModel.fromJson(snap.data()!);
    _memberCache[id] = member;
    return member;
  }

  /// Busca o bitmask de um cargo (com cache).
  Future<int> getRoleBitmask(String groupId, String roleId) async {
    final key = '${groupId}_$roleId';
    final cached = _roleCache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.bitmask;
    }
    final snap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roles')
        .doc(roleId)
        .get();
    if (!snap.exists || snap.data() == null) {
      throw FirestoreException(
        message: 'role-not-found: $groupId/$roleId',
      );
    }
    final role = RoleModel.fromJson(snap.data()!);
    _roleCache[key] = _CachedBitmask(role.permissionsBitmask);
    return role.permissionsBitmask;
  }

  /// Invalida o cache de um cargo (usado após `MembershipService`
  /// alterar permissões).
  void invalidateRole(String groupId, String roleId) {
    _roleCache.remove('${groupId}_$roleId');
  }

  void invalidateMember(String groupId, String userId) {
    _memberCache.remove(_membershipDocId(groupId, userId));
  }

  /// Resolve as permissões efetivas de um usuário num grupo.
  /// Não considera overrides de canal — use [resolveForChannel] para isso.
  Future<ResolvedPermissions> resolveForGroup({
    required String groupId,
    required String userId,
    required String groupOwnerId,
  }) async {
    final member = await getMember(groupId: groupId, userId: userId);
    if (member == null) {
      // Não é membro = sem permissão.
      return const ResolvedPermissions(bitmask: 0, isOwner: false);
    }
    final isOwner = groupOwnerId == userId;
    if (isOwner) {
      // Owner: nem precisa buscar o cargo, mas carrega para auditoria.
      try {
        await getRoleBitmask(groupId, member.roleId);
      } on AppException catch (e) {
        Logger.w('Owner sem cargo válido? ${e.message}');
      }
      return ResolvedPermissions(bitmask: 0, isOwner: true);
    }
    final bitmask = await getRoleBitmask(groupId, member.roleId);
    return ResolvedPermissions(bitmask: bitmask, isOwner: false);
  }

  /// Resolve as permissões em um canal (aplica override).
  Future<ResolvedPermissions> resolveForChannel({
    required String groupId,
    required String channelId,
    required String userId,
    required String groupOwnerId,
    required int channelPermissionOverrides,
  }) async {
    final base = await resolveForGroup(
      groupId: groupId,
      userId: userId,
      groupOwnerId: groupOwnerId,
    );
    return ResolvedPermissions(
      bitmask: base.bitmask | channelPermissionOverrides,
      isOwner: base.isOwner,
    );
  }

  /// Recusa promoção que dê ao alvo um bit que o autor não tem.
  ///
  /// Use antes de chamar `MembershipService.changeMemberRole`:
  /// ```dart
  /// resolver.assertNoPrivilegeEscalation(
  ///   actingUserBitmask: actingEffective,
  ///   targetBitmask: newRole.permissionsBitmask,
  /// );
  /// ```
  ///
  /// Lança [AuthException] (reaproveitada para erro de autorização)
  /// se o alvo receber bits que o autor não possui.
  void assertNoPrivilegeEscalation({
    required int actingUserBitmask,
    required int targetBitmask,
  }) {
    // Bits extras que o alvo ganharia e que o autor não tem.
    final extra = targetBitmask & ~actingUserBitmask;
    if (extra != 0) {
      throw AuthException(
        message:
            'privilege-escalation: bits=${PermissionKeys.keyForBit(extra)}',
      );
    }
  }
}

class _CachedBitmask {
  _CachedBitmask(this.bitmask);
  final int bitmask;
  final DateTime fetchedAt = DateTime.now();
}

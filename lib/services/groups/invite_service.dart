/// `InviteService` — códigos de convite para entrar em grupos.
///
/// Fluxo:
/// 1. Usuário com `manageInvites` (ou owner) chama `createInvite`.
/// 2. Compartilha o `code` (ex: link com `?invite=ABCD1234`).
/// 3. Quem recebe chama `consumeInvite(code, userId)` — o serviço
///    valida `expiresAt`/`uses < maxUses` em transação atômica,
///    e chama `MembershipService.addMember` com o cargo `member`.
///
/// Coleção: `invites/{code}` (índice em `groupId`).
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/invite_model.dart';
import 'membership_service.dart';

class InviteService {
  InviteService({
    FirebaseFirestore? firestore,
    MembershipService? membershipService,
    Random? random,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _membership = membershipService ?? MembershipService(),
        _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final MembershipService _membership;
  final Random _random;

  /// Gera um código curto (A-Z, 0-9) sem ambiguidade (sem I/O/0/1).
  /// 8 chars => ~30 bits de entropia — suficiente para convites.
  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Cria um convite. O `actingUserId` deve ter `manageInvites` ou
  /// ser o owner.
  Future<InviteModel> createInvite({
    required String groupId,
    required String actingUserId,
    int maxUses = 1,
    Duration validFor = const Duration(days: 7),
  }) async {
    final groupSnap = await _firestore.collection('groups').doc(groupId).get();
    if (!groupSnap.exists || groupSnap.data() == null) {
      throw const FirestoreException(message: 'group-not-found');
    }
    final ownerId = groupSnap.data()!['ownerId'] as String;
    if (ownerId != actingUserId) {
      // checagem leve: o PermissionResolver.resolveForGroup já faria isso,
      // mas aqui só precisamos de manageInvites. Para não acoplar este
      // service ao resolver, delegamos ao caller (UI) passar actingUserId
      // que de fato tem permissão — Firestore Rules são a fonte da verdade.
      // Em client-side, a UI chamará PermissionResolver antes de chegar aqui.
    }
    if (maxUses < 1) {
      throw const AuthException(message: 'invalid-max-uses');
    }
    final now = DateTime.now();
    final code = _generateCode();
    final invite = InviteModel(
      code: code,
      groupId: groupId,
      createdBy: actingUserId,
      expiresAt: now.add(validFor),
      maxUses: maxUses,
      uses: 0,
      createdAt: now,
    );
    try {
      await _firestore.collection('invites').doc(code).set(invite.toJson());
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
    Logger.i('InviteService: convite $code para $groupId criado por $actingUserId');
    return invite;
  }

  /// Consome um convite: valida + adiciona membro em transação.
  /// Lança [AuthException] se o convite estiver expirado, exaurido,
  /// inválido ou se o usuário já for membro.
  Future<String> consumeInvite({
    required String code,
    required String userId,
  }) async {
    final inviteRef = _firestore.collection('invites').doc(code);
    String addedGroupId = '';
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(inviteRef);
        if (!snap.exists || snap.data() == null) {
          throw const AuthException(message: 'invite-not-found');
        }
        final invite = InviteModel.fromJson(snap.data()!);
        if (invite.isExpired) {
          throw const AuthException(message: 'invite-expired');
        }
        if (invite.isExhausted) {
          throw const AuthException(message: 'invite-exhausted');
        }
        final memberId = '${invite.groupId}_$userId';
        final memberRef = _firestore.collection('memberships').doc(memberId);
        final memberSnap = await tx.get(memberRef);
        if (memberSnap.exists) {
          addedGroupId = invite.groupId;
          return; // idempotente
        }
        tx.update(inviteRef, <String, dynamic>{
          'uses': FieldValue.increment(1),
        });
        tx.set(memberRef, <String, dynamic>{
          'groupId': invite.groupId,
          'userId': userId,
          'roleId': 'member',
          'joinedAt': DateTime.now().toIso8601String(),
        });
        tx.update(
          _firestore.collection('groups').doc(invite.groupId),
          <String, dynamic>{'memberCount': FieldValue.increment(1)},
        );
        addedGroupId = invite.groupId;
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    } on AuthException {
      rethrow;
    } catch (e, st) {
      throw AuthException(message: e.toString(), stackTrace: st);
    }
    return addedGroupId;
  }

  /// Stream dos convites de um grupo (para gerenciamento).
  Stream<List<InviteModel>> watchGroupInvites(String groupId) {
    return _firestore
        .collection('invites')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InviteModel.fromJson(d.data()))
            .toList(growable: false));
  }

  /// Revoga um convite (apaga). Não checa permissão aqui — UI/Service
  /// de chamada devem validar `manageInvites`.
  Future<void> revokeInvite({
    required String code,
    required String actingUserId,
  }) async {
    try {
      await _firestore.collection('invites').doc(code).delete();
      Logger.i('InviteService: convite $code revogado por $actingUserId');
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }
}

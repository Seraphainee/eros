/// Modelo de dados para Membership (relação usuário-grupo).
///
/// Armazenado em `memberships/{groupId + userId}` (índice composto).
/// Conecta um usuário a um grupo com seu cargo específico.
///
/// Implementação manual imutável — idêntica estratégia do `user_model`
/// e do `group_model`. Quando o `build_runner` rodar, este arquivo
/// será migrado para `@freezed` preservando a API pública.
class MemberModel {
  const MemberModel({
    required this.groupId,
    required this.userId,
    required this.roleId,
    required this.joinedAt,
    this.currentRoleId,
  });

  /// ID do grupo (chave primária parcial).
  final String groupId;

  /// ID do usuário (chave primária parcial).
  final String userId;

  /// ID do cargo (referência a `groups/{groupId}/roles/{roleId}`).
  final String roleId;

  /// Quando o usuário entrou no grupo.
  final DateTime joinedAt;

  /// Cargos atuais do usuário naquele grupo (para refresh de permissões).
  final String? currentRoleId;

  /// ID do documento Firestore: `{groupId}_{userId}`.
  String get docId => '${groupId}_$userId';

  MemberModel copyWith({
    String? groupId,
    String? userId,
    String? roleId,
    DateTime? joinedAt,
    String? currentRoleId,
  }) {
    return MemberModel(
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      roleId: roleId ?? this.roleId,
      joinedAt: joinedAt ?? this.joinedAt,
      currentRoleId: currentRoleId ?? this.currentRoleId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'userId': userId,
        'roleId': roleId,
        'joinedAt': joinedAt.toIso8601String(),
        'currentRoleId': currentRoleId,
      };

  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
        groupId: json['groupId'] as String,
        userId: json['userId'] as String,
        roleId: json['roleId'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        currentRoleId: json['currentRoleId'] as String?,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberModel &&
        other.groupId == groupId &&
        other.userId == userId &&
        other.roleId == roleId &&
        other.joinedAt == joinedAt &&
        other.currentRoleId == currentRoleId;
  }

  @override
  int get hashCode => Object.hash(groupId, userId, roleId, joinedAt, currentRoleId);

  @override
  String toString() => 'MemberModel(groupId: $groupId, userId: $userId, roleId: $roleId)';
}

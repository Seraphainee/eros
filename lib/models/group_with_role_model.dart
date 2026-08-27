/// View local: `GroupModel` + `MemberModel` + `RoleModel`.
///
/// Não é persistido no Firestore — é a composição que a UI usa
/// para listar "meus grupos" exibindo o nome do meu cargo em cada um.
class GroupWithRole {
  const GroupWithRole({
    required this.group,
    required this.member,
    required this.role,
  });

  final dynamic group;     // GroupModel
  final dynamic member;     // MemberModel
  final dynamic role;       // RoleModel

  /// UID do usuário membro (igual em `member.userId`).
  String get userId => member.userId as String;

  @override
  String toString() => 'GroupWithRole(group: ${group.id}, role: ${role.name})';
}

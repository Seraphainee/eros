/// Modelo de dados para Role (cargos dentro de um grupo).
///
/// Define permissões via bitmask (PermissionKeys) aplicáveis a membros
/// do grupo. Armazenado em `groups/{groupId}/roles/{roleId}`.
///
/// Implementação manual imutável — idêntica estratégia dos outros models.
class RoleModel {
  const RoleModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.permissionsBitmask,
    required this.createdAt,
  });

  /// ID único do cargo dentro do grupo.
  final String id;

  /// ID do grupo ao qual o cargo pertence.
  final String groupId;

  /// Nome legível do cargo (ex: "Owner", "Admin", "Moderador", "VIP").
  final String name;

  /// Bitmask que representa as permissões deste cargo.
  /// Cada bit representa uma permissão (ver [PermissionKeys]).
  final int permissionsBitmask;

  /// Quando o cargo foi criado.
  final DateTime createdAt;

  /// Verifica se o cargo tem uma permissão específica.
  bool hasPermission(int permissionBit) =>
      (permissionsBitmask & permissionBit) != 0;

  RoleModel copyWith({
    String? id,
    String? groupId,
    String? name,
    int? permissionsBitmask,
    DateTime? createdAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      permissionsBitmask: permissionsBitmask ?? this.permissionsBitmask,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'groupId': groupId,
        'name': name,
        'permissionsBitmask': permissionsBitmask,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        name: json['name'] as String,
        permissionsBitmask: (json['permissionsBitmask'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoleModel &&
        other.id == id &&
        other.groupId == groupId &&
        other.name == name &&
        other.permissionsBitmask == permissionsBitmask &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, name, permissionsBitmask, createdAt);

  @override
  String toString() => 'RoleModel(id: $id, name: $name, bitmask: $permissionsBitmask)';
}

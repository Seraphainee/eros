/// Modelo de dados para Group.
///
/// Documento em `groups/{groupId}`. Apenas metadados públicos do grupo
/// — membros e cargos ficam em coleções separadas (`memberships` e
/// `groups/{groupId}/roles`).
///
/// Implementação manual imutável nesta etapa; quando o gerador
/// `freezed`/`json_serializable` rodar, o arquivo será migrado
/// preservando a API pública (`copyWith`, `toJson`/`fromJson`,
/// `==`/`hashCode`).
class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.iconUrl,
    required this.createdAt,
    this.memberCount = 1,
  });

  /// ID do grupo (= `groups/{id}`).
  final String id;

  /// Nome legível do grupo (3..64 chars, validado em service).
  final String name;

  /// UID do dono (não muda após a criação; usado pelo `PermissionResolver`).
  final String ownerId;

  /// URL do ícone no Firebase Storage (opcional).
  final String? iconUrl;

  /// Quando o grupo foi criado.
  final DateTime createdAt;

  /// Cache de contagem de membros para evitar `count()` em queries.
  /// Mantido pelo `MembershipService` em writes de add/remove.
  final int memberCount;

  GroupModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? iconUrl,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      iconUrl: iconUrl ?? this.iconUrl,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'iconUrl': iconUrl,
        'createdAt': createdAt.toIso8601String(),
        'memberCount': memberCount,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['ownerId'] as String,
        iconUrl: json['iconUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        memberCount: (json['memberCount'] as int?) ?? 1,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupModel &&
        other.id == id &&
        other.name == name &&
        other.ownerId == ownerId &&
        other.iconUrl == iconUrl &&
        other.createdAt == createdAt &&
        other.memberCount == memberCount;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, ownerId, iconUrl, createdAt, memberCount);

  @override
  String toString() =>
      'GroupModel(id: $id, name: $name, ownerId: $ownerId, memberCount: $memberCount)';
}

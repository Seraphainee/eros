/// Modelo de dados para Group.
///
/// Documento em `groups/{groupId}`. Apenas metadados públicos do grupo
/// — membros e cargos ficam em coleções separadas (`memberships` e
/// `groups/{groupId}/roles`).
import '../core/constants/ranking_constants.dart';

class GroupModel {
  const GroupModel({
    required this.id,
    required this.numericId,
    required this.name,
    required this.ownerId,
    this.iconUrl,
    this.slogan,
    required this.createdAt,
    this.memberCount = 1,
    this.contributionPoints = 0,
    this.likeCount = 0,
  });

  final String id;
  final int numericId;
  final String name;
  final String ownerId;
  final String? iconUrl;

  /// Frase curta exibida abaixo do nome (equivalente ao "SLOGAN" da
  /// tela de Configurações do grupo). Opcional.
  final String? slogan;

  final DateTime createdAt;
  final int memberCount;

  /// Pontos acumulados pelo grupo (voz + mensagens + eventos),
  /// somados via `RankingConstants`. Alimenta `level` e `progress`.
  final int contributionPoints;

  /// Contagem de curtidas (cache; a fonte de verdade é a subcoleção
  /// `groups/{groupId}/likes/{userId}`, mantida pelo `GroupService`).
  final int likeCount;

  /// Representação exibida na UI, ex: "#2800".
  String get displayId => '#$numericId';

  /// Nível atual do grupo, derivado de [contributionPoints].
  int get level => RankingConstants.levelForPoints(contributionPoints);

  /// Pontos que faltam para o próximo nível (null se nível máximo).
  int? get pointsToNextLevel =>
      RankingConstants.pointsToNextLevel(contributionPoints);

  /// Progresso (0.0..1.0) dentro do nível atual.
  double get levelProgress =>
      RankingConstants.progressInLevel(contributionPoints);

  GroupModel copyWith({
    String? id,
    int? numericId,
    String? name,
    String? ownerId,
    String? iconUrl,
    String? slogan,
    DateTime? createdAt,
    int? memberCount,
    int? contributionPoints,
    int? likeCount,
  }) {
    return GroupModel(
      id: id ?? this.id,
      numericId: numericId ?? this.numericId,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      iconUrl: iconUrl ?? this.iconUrl,
      slogan: slogan ?? this.slogan,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      contributionPoints: contributionPoints ?? this.contributionPoints,
      likeCount: likeCount ?? this.likeCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'numericId': numericId,
        'name': name,
        'ownerId': ownerId,
        'iconUrl': iconUrl,
        'slogan': slogan,
        'createdAt': createdAt.toIso8601String(),
        'memberCount': memberCount,
        'contributionPoints': contributionPoints,
        'likeCount': likeCount,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        numericId: (json['numericId'] as int?) ?? 0,
        name: json['name'] as String,
        ownerId: json['ownerId'] as String,
        iconUrl: json['iconUrl'] as String?,
        slogan: json['slogan'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        memberCount: (json['memberCount'] as int?) ?? 1,
        contributionPoints: (json['contributionPoints'] as int?) ?? 0,
        likeCount: (json['likeCount'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupModel &&
        other.id == id &&
        other.numericId == numericId &&
        other.name == name &&
        other.ownerId == ownerId &&
        other.iconUrl == iconUrl &&
        other.slogan == slogan &&
        other.createdAt == createdAt &&
        other.memberCount == memberCount &&
        other.contributionPoints == contributionPoints &&
        other.likeCount == likeCount;
  }

  @override
  int get hashCode => Object.hash(id, numericId, name, ownerId, iconUrl,
      slogan, createdAt, memberCount, contributionPoints, likeCount);

  @override
  String toString() =>
      'GroupModel(id: $id, numericId: $numericId, name: $name, level: $level)';
}
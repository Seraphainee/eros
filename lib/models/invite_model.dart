/// Modelo de dados para Invite (convite de grupo).
///
/// Documento em `invites/{code}`. `code` é gerado pelo `InviteService`
/// como string aleatória de 8 caracteres alfanuméricos (A-Z, 0-9),
/// para reduzir chance de colisão e ser digitável.
///
/// Implementação manual imutável — mesma estratégia dos outros models.
class InviteModel {
  const InviteModel({
    required this.code,
    required this.groupId,
    required this.createdBy,
    required this.expiresAt,
    required this.maxUses,
    required this.uses,
    required this.createdAt,
  });

  /// Código curto usado como chave do doc e a ser compartilhado.
  final String code;

  /// ID do grupo que o convite adiciona.
  final String groupId;

  /// UID de quem criou o convite (para auditoria).
  final String createdBy;

  /// Quando o convite expira (após isto, `consumeInvite` falha).
  final DateTime expiresAt;

  /// Máximo de usos (0 = ilimitado? Não — usamos 1 como default
  /// e `int.maxValue` como "ilimitado" para evitar ambiguidade).
  final int maxUses;

  /// Usos consumidos até o momento.
  final int uses;

  /// Quando o convite foi criado.
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExhausted => uses >= maxUses;
  bool get isUsable => !isExpired && !isExhausted;
  int get remainingUses => (maxUses - uses).clamp(0, maxUses);

  InviteModel copyWith({
    String? code,
    String? groupId,
    String? createdBy,
    DateTime? expiresAt,
    int? maxUses,
    int? uses,
    DateTime? createdAt,
  }) {
    return InviteModel(
      code: code ?? this.code,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      uses: uses ?? this.uses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'groupId': groupId,
        'createdBy': createdBy,
        'expiresAt': expiresAt.toIso8601String(),
        'maxUses': maxUses,
        'uses': uses,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InviteModel.fromJson(Map<String, dynamic> json) => InviteModel(
        code: json['code'] as String,
        groupId: json['groupId'] as String,
        createdBy: json['createdBy'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        maxUses: (json['maxUses'] as int?) ?? 1,
        uses: (json['uses'] as int?) ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InviteModel &&
        other.code == code &&
        other.groupId == groupId &&
        other.createdBy == createdBy &&
        other.expiresAt == expiresAt &&
        other.maxUses == maxUses &&
        other.uses == uses &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
      code, groupId, createdBy, expiresAt, maxUses, uses, createdAt);

  @override
  String toString() =>
      'InviteModel(code: $code, groupId: $groupId, uses: $uses/$maxUses)';
}

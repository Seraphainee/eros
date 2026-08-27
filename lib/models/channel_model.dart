/// Modelo de dados para Channel (texto ou voz).
///
/// Documento em `channels/{channelId}`. Coleção raiz (não aninhada
/// em `groups/{groupId}/...`) para permitir queries globais como
/// "todos os canais de voz ativos do usuário" sem sub-coleção.
///
/// `permissionOverrides` é um bitmask (int) aplicado POR CIMA do
/// bitmask do cargo: bits ligados = `ALLOW`, bits desligados
/// comparados ao default = `DENY` se explicitamente listados. Para
/// evitar semântica ambígua, esta etapa usa apenas ALLOW explícito
/// (OR com o bitmask do cargo). DENY por canal fica como
/// extensão futura.
///
/// Implementação manual imutável — mesma estratégia dos outros
/// models desta etapa.
enum ChannelType { text, voice }

class ChannelModel {
  const ChannelModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    required this.order,
    this.permissionOverrides = 0,
    required this.createdAt,
  });

  /// ID do canal.
  final String id;

  /// ID do grupo dono.
  final String groupId;

  /// Nome do canal (sem `#`; UI adiciona).
  final String name;

  /// Tipo: texto ou voz.
  final ChannelType type;

  /// Posição na sidebar do grupo (0-based). Atualizado por
  /// `ChannelService.reorderChannels`.
  final int order;

  /// Bits adicionados ao bitmask do usuário neste canal (ALLOW only).
  /// Default 0 = segue o bitmask do cargo.
  final int permissionOverrides;

  /// Quando o canal foi criado.
  final DateTime createdAt;

  bool get isText => type == ChannelType.text;
  bool get isVoice => type == ChannelType.voice;

  ChannelModel copyWith({
    String? id,
    String? groupId,
    String? name,
    ChannelType? type,
    int? order,
    int? permissionOverrides,
    DateTime? createdAt,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      type: type ?? this.type,
      order: order ?? this.order,
      permissionOverrides: permissionOverrides ?? this.permissionOverrides,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'groupId': groupId,
        'name': name,
        'type': type.name,
        'order': order,
        'permissionOverrides': permissionOverrides,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChannelModel.fromJson(Map<String, dynamic> json) => ChannelModel(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        name: json['name'] as String,
        type: ChannelType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ChannelType.text,
        ),
        order: (json['order'] as int?) ?? 0,
        permissionOverrides: (json['permissionOverrides'] as int?) ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelModel &&
        other.id == id &&
        other.groupId == groupId &&
        other.name == name &&
        other.type == type &&
        other.order == order &&
        other.permissionOverrides == permissionOverrides &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
      id, groupId, name, type, order, permissionOverrides, createdAt);

  @override
  String toString() =>
      'ChannelModel(id: $id, groupId: $groupId, name: $name, type: $type, order: $order)';
}

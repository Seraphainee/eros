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

/// Quem pode falar em um canal de voz (irrelevante para canais de
/// texto). Réplica do seletor "MODO DE VOZ" da tela de criação.
enum VoiceMode {
  /// Qualquer membro pode ligar o microfone livremente.
  free,

  /// Só admins/moderadores podem falar; demais ficam mutados.
  admin,

  /// Membros entram numa fila e falam um de cada vez.
  queue,
}

/// Quem pode ver/entrar no canal. Réplica do seletor "Visibilidade"
/// da tela de criação.
enum ChannelVisibility {
  /// Visível e acessível a qualquer membro do grupo.
  public,

  /// Visível apenas para membros com um cargo específico
  /// (refinamento fica a cargo do `permissionOverrides`).
  membersOnly,

  /// Membros podem ver mas só administradores podem postar/falar.
  announcementsOnly,

  /// Oculto para quem não tiver acesso explícito.
  private,
}

class ChannelModel {
  const ChannelModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    required this.order,
    this.permissionOverrides = 0,
    this.voiceMode = VoiceMode.free,
    this.visibility = ChannelVisibility.public,
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

  /// Quem pode falar (apenas relevante quando [type] é voz).
  final VoiceMode voiceMode;

  /// Quem pode ver/acessar o canal.
  final ChannelVisibility visibility;

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
    VoiceMode? voiceMode,
    ChannelVisibility? visibility,
    DateTime? createdAt,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      type: type ?? this.type,
      order: order ?? this.order,
      permissionOverrides: permissionOverrides ?? this.permissionOverrides,
      voiceMode: voiceMode ?? this.voiceMode,
      visibility: visibility ?? this.visibility,
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
        'voiceMode': voiceMode.name,
        'visibility': visibility.name,
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
        voiceMode: VoiceMode.values.firstWhere(
          (e) => e.name == json['voiceMode'],
          orElse: () => VoiceMode.free,
        ),
        visibility: ChannelVisibility.values.firstWhere(
          (e) => e.name == json['visibility'],
          orElse: () => ChannelVisibility.public,
        ),
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
        other.voiceMode == voiceMode &&
        other.visibility == visibility &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, groupId, name, type, order,
      permissionOverrides, voiceMode, visibility, createdAt);

  @override
  String toString() =>
      'ChannelModel(id: $id, groupId: $groupId, name: $name, type: $type, order: $order)';
}
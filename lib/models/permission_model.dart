/// Modelo de dados para Permission (permissões individuais).
///
/// Representa uma única permissão que pode ser concedida a cargos ou
/// canais. Usado por: `PermissionResolver` (espelho local do esquema
/// de permissões), `channel_permission_service` (regras de negócio).
///
/// Implementação manual imutável — idêntica estratégia dos outros models.
class PermissionModel {
  const PermissionModel({
    required this.key,
    required this.name,
    required this.description,
    required this.isDefaultEnabled,
    required this.adminOnly,
  });

  /// Identificação única da permissão (permite iteração programática).
  final String key;

  /// Nome legível para UI (ex: "Gerenciar canais", "Kick membros").
  final String name;

  /// Descrição de uma linha para tooltips/dica de ferramenta.
  final String description;

  /// Ativa por padrão? (usado por cargos padrão em novos grupos).
  final bool isDefaultEnabled;

  /// Requer admin/grupo full control? (impede escalonamento de permissão).
  final bool adminOnly;
}

/// Bits do permission_model (guarda de bits para role_model).
///
/// Cada permissão é representada por um único bit (1 << índice). Usado por:
/// - `role_model`: `permissionsBitmask` armazena OR de várias PermissionKeys
/// - `channel_permission_service`: sobreposições de permissão de canal
class PermissionKeys {
  PermissionKeys._();

  // --- Bits ---
  /// Criar/renomear/excluir canais de texto e voz.
  static const int manageChannels = 1 << 0;

  /// Alterar perfil de cargo, adicionar/excluir cargos.
  static const int manageRoles = 1 << 1;

  /// Remover membros do grupo (exceto o owner).
  static const int kickMembers = 1 << 2;

  /// Silenciar microfones de outros membros em canais de voz.
  static const int muteMembers = 1 << 3;

  /// Permitir falar no canal de voz.
  static const int speakInVoice = 1 << 4;

  /// Enviar mensagens de texto em canais textuais.
  static const int sendMessages = 1 << 5;

  /// Visualizar mensagens anteriores em canais textuais.
  static const int readHistory = 1 << 6;

  /// Criar e gerenciar convites de grupo.
  static const int manageInvites = 1 << 7;

  /// Todos os bits de permissão para validação.
  static List<int> get allKeys => <int>[
        manageChannels,
        manageRoles,
        kickMembers,
        muteMembers,
        speakInVoice,
        sendMessages,
        readHistory,
        manageInvites,
      ];

  /// Bitmask com todas as permissões (cargo Owner).
  static int get allBits {
    int acc = 0;
    for (final b in allKeys) {
      acc |= b;
    }
    return acc;
  }

  /// Bitmask padrão do cargo Member (permissões não-admin).
  static int get defaultMemberBits =>
      speakInVoice | sendMessages | readHistory;

  /// Mapeia bit -> chave para iteração reversa.
  static String keyForBit(int bit) {
    switch (bit) {
      case manageChannels:
        return 'manageChannels';
      case manageRoles:
        return 'manageRoles';
      case kickMembers:
        return 'kickMembers';
      case muteMembers:
        return 'muteMembers';
      case speakInVoice:
        return 'speakInVoice';
      case sendMessages:
        return 'sendMessages';
      case readHistory:
        return 'readHistory';
      case manageInvites:
        return 'manageInvites';
      default:
        return 'unknown';
    }
  }

  /// Lista completa de PermissionModel para a UI de gerenciamento.
  static List<PermissionModel> get allPermissions => <PermissionModel>[
        const PermissionModel(
          key: 'manageChannels',
          name: 'Gerenciar canais',
          description: 'Criar, renomear, excluir canais de texto e voz.',
          isDefaultEnabled: false,
          adminOnly: true,
        ),
        const PermissionModel(
          key: 'manageRoles',
          name: 'Gerenciar cargos',
          description: 'Alterar perfil de cargo, adicionar/excluir cargos.',
          isDefaultEnabled: false,
          adminOnly: true,
        ),
        const PermissionModel(
          key: 'kickMembers',
          name: 'Expulsar membros',
          description: 'Remover membros de grupos (exceto membros donos).',
          isDefaultEnabled: true,
          adminOnly: false,
        ),
        const PermissionModel(
          key: 'muteMembers',
          name: 'Silenciar membros',
          description: 'Silenciar microfones em canais de voz.',
          isDefaultEnabled: true,
          adminOnly: false,
        ),
        const PermissionModel(
          key: 'speakInVoice',
          name: 'Falar em voz',
          description: 'Permitir falar no canal de voz.',
          isDefaultEnabled: true,
          adminOnly: false,
        ),
        const PermissionModel(
          key: 'sendMessages',
          name: 'Enviar mensagens',
          description: 'Enviar mensagens de texto em canais textuais.',
          isDefaultEnabled: true,
          adminOnly: false,
        ),
        const PermissionModel(
          key: 'readHistory',
          name: 'Ver histórico',
          description: 'Visualizar mensagens anteriores em canais textuais.',
          isDefaultEnabled: true,
          adminOnly: false,
        ),
        const PermissionModel(
          key: 'manageInvites',
          name: 'Gerenciar convites',
          description: 'Criar e gerenciar convites de grupo.',
          isDefaultEnabled: false,
          adminOnly: true,
        ),
      ];
}

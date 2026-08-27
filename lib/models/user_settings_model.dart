/// Modelo de dados para UserSettings (configurações privadas do usuário).
///
/// Armazenado no Firestone em `user_settings/{userId}`.
/// Contém preferências que o usuário controla e não são públicas.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings_model.freezed.dart';
part 'user_settings_model.g.dart';

@freezed
class UserSettingsModel with _$UserSettingsModel {
  const factory UserSettingsModel({
    /// ID do usuário (chave primária - referência para users/{uid}).
    required String userId,

    /// Preferências de áudio.
    required AudioPrefs audioPrefs,

    /// Preferências de notificação.
    required NotificationPrefs notifPrefs,

    /// Preferências de privacidade.
    required PrivacyPrefs privacyPrefs,

    /// Quando o registro foi atualizado.
    required DateTime updatedAt,
  }) = _UserSettingsModel;

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsModelFromJson(json);
}

@freezed
class AudioPrefs with _$AudioPrefs {
  const factory AudioPrefs({
    /// Volume geral (0.0 a 1.0).
    required double volume,

    /// Volume do microfone (0.0 a 1.0).
    required double micVolume,

    /// Se está usando fones de ouvido.
    required bool useHeadset,

    /// Ativar supressão de ruído (WebRTC).
    required bool noiseSuppression,

    /// Ativar cancelamento de eco (WebRTC).
    required bool echoCancellation,
  }) = _AudioPrefs;

  factory AudioPrefs.fromJson(Map<String, dynamic> json) =>
      _$AudioPrefsFromJson(json);
}

@freezed
class NotificationPrefs with _$NotificationPrefs {
  const factory NotificationPrefs({
    /// Habilitar notificações push.
    required bool pushEnabled,

    /// Habilitar notificações de menção em chat.
    required bool mentionEnabled,

    /// Habilitar notificações de entrada/saída de sala de voz.
    required bool voiceJoinLeaveEnabled,

    /// Habilitar notificações de convite de grupo.
    required bool groupInviteEnabled,

    /// Som de notificação personalizado (caminho do asset ou null para padrão).
    String? customSoundPath,

    /// Não perturbar: horário de início (HH:mm).
    TimeOfDay? dndStart,

    /// Não perturbar: horário de fim (HH:mm).
    TimeOfDay? dndEnd,
  }) = _NotificationPrefs;

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsFromJson(json);
}

@freezed
class PrivacyPrefs with _$PrivacyPrefs {
  const factory PrivacyPrefs({
    /// Quem pode enviar mensagem direta.
    required DirectMessagePolicy directMessagePolicy,

    /// Quem pode ver seu status (online/offline/inRoom).
    required StatusVisibilityPolicy statusVisibility,

    /// Permitir que estranhos o adicionem a grupos via convite.
    required bool allowGroupInvitesFromStrangers,

    /// Ocultar seu status de atividade (último visto).
    required bool hideActivityStatus,

    /// Bloquear usuários (lista de userIds).
    required List<String> blockedUserIds,
  }) = _PrivacyPrefs;

  factory PrivacyPrefs.fromJson(Map<String, dynamic> json) =>
      _$PrivacyPrefsFromJson(json);
}

enum DirectMessagePolicy { everyone, friendsOnly, nobody }

enum StatusVisibilityPolicy { everyone, friendsOnly, nobody }
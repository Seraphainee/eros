/// Modelo de dados para Presence (estado online/offline/emSala).
///
/// Armazenado no Firestore em `presence/{userId}` e expira após um
/// período de inatividade (para evitar necessidade de manutenção excessiva).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presence_model.freezed.dart';
part 'presence_model.g.dart';

@freezed
class PresenceModel with _$PresenceModel {
  const factory PresenceModel({
    /// ID do usuário (chave primária - referência para users/{uid}).
    required String userId,

    /// Estado atual do usuário.
    required UserPresenceState state,

    /// ID do grupo ou canal em que o usuário está presente (null se offline).
    String? roomId,

    /// Referência para o canal de voz em que o usuário está falando (null se não falando).
    String? voiceChannelId,

    /// Timestamp do último evento que atualizou este registro (Firestone lido).
    required DateTime lastSeen,

    /// Metadados adicionais: IP, dispositivo, etc. (opcional para depuração).
    Map<String, dynamic>? metadata,
  }) = _PresenceModel;

  factory PresenceModel.fromJson(Map<String, dynamic> json) =>
      _$PresenceModelFromJson(json);
}

/// Estados possíveis para um usuário no app (igual UserStatus mas mais específico para presença).
enum UserPresenceState {
  offline,
  online,
  inRoom,
  away,
}
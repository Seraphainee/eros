/// Modelo de dados para o estado de uma sala de voz.
///
/// Não é persistido — é construído pelo `VoiceRoomService` a partir
/// dos eventos do `livekit_client.Room`.
class VoiceRoomState {
  const VoiceRoomState({
    required this.connectionState,
    required this.participants,
    this.channelId,
    this.errorMessage,
  });

  /// Estado da conexão.
  final VoiceConnectionState connectionState;

  /// ID do canal de voz (null quando desconectado).
  final String? channelId;

  /// Lista de participantes atualmente na sala.
  final List<VoiceParticipantModel> participants;

  /// Mensagem de erro (quando `connectionState == failed`).
  final String? errorMessage;

  int get participantCount => participants.length;
  bool get isConnected => connectionState == VoiceConnectionState.connected;
  bool get isInRoom =>
      connectionState == VoiceConnectionState.connected ||
      connectionState == VoiceConnectionState.reconnecting;

  /// Estado inicial (desconectado).
  static const VoiceRoomState initial = VoiceRoomState(
    connectionState: VoiceConnectionState.disconnected,
    participants: <VoiceParticipantModel>[],
  );

  VoiceRoomState copyWith({
    VoiceConnectionState? connectionState,
    String? channelId,
    List<VoiceParticipantModel>? participants,
    String? errorMessage,
    bool clearChannel = false,
    bool clearError = false,
  }) {
    return VoiceRoomState(
      connectionState: connectionState ?? this.connectionState,
      channelId: clearChannel ? null : (channelId ?? this.channelId),
      participants: participants ?? this.participants,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

enum VoiceConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

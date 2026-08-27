/// Modelo de dados para um participante de sala de voz.
///
/// Não é persistido — é construído a partir dos eventos do
/// `livekit_client.Room` (wrapper em `webrtc_client.dart`).
///
/// Implementação manual imutável — idêntica estratégia dos outros models.
class VoiceParticipantModel {
  const VoiceParticipantModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.isMuted,
    required this.isSpeaking,
    required this.isLocal,
    required this.joinedAt,
  });

  /// UID do participante.
  final String userId;

  /// Nome de exibição (vem de `users/{uid}.displayName` no Firestore,
  /// ou fallback para o uid encurtado).
  final String displayName;

  /// Foto de perfil (opcional).
  final String? photoUrl;

  /// Mic mutado pelo próprio usuário.
  final bool isMuted;

  /// Indicador de fala ativa (VAD do LiveKit).
  final bool isSpeaking;

  /// `true` para o usuário local (este device).
  final bool isLocal;

  /// Quando entrou na sala (server time).
  final DateTime joinedAt;

  VoiceParticipantModel copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    bool? isMuted,
    bool? isSpeaking,
    bool? isLocal,
    DateTime? joinedAt,
  }) {
    return VoiceParticipantModel(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isLocal: isLocal ?? this.isLocal,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceParticipantModel &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.isMuted == isMuted &&
        other.isSpeaking == isSpeaking &&
        other.isLocal == isLocal &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        displayName,
        photoUrl,
        isMuted,
        isSpeaking,
        isLocal,
        joinedAt,
      );

  @override
  String toString() =>
      'VoiceParticipantModel(userId: $userId, displayName: $displayName, '
      'isMuted: $isMuted, isSpeaking: $isSpeaking)';
}

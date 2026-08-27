/// `VoiceSignalingService` — side-channel Firestore para signaling
/// (ofertas SDP/ICE, eventos de join/leave por par).
///
/// **STUB para Etapa 5**: o LiveKit já faz o signaling internamente
/// (server-side via WebSocket). Esta classe existe para:
/// 1. Documentar a interface pretendida.
/// 2. Servir de ponto de extensão se a Etapa 5 migrar para
///    `flutter_webrtc` P2P.
///
/// Coleção: `voice_signaling/{roomId}/messages/{messageId}` —
/// mensagens efêmeras com TTL (cloud function de limpeza).
class VoiceSignalingService {
  VoiceSignalingService();

  /// Stub: publica uma oferta SDP para o par.
  Future<void> publishOffer({
    required String roomId,
    required String targetUserId,
    required String sdp,
  }) async {
    // TODO(etapa-5): implementar.
    throw UnimplementedError('VoiceSignalingService.publishOffer (Etapa 5)');
  }

  /// Stub: publica uma resposta SDP.
  Future<void> publishAnswer({
    required String roomId,
    required String targetUserId,
    required String sdp,
  }) async {
    throw UnimplementedError('VoiceSignalingService.publishAnswer (Etapa 5)');
  }

  /// Stub: publica um candidato ICE.
  Future<void> publishIceCandidate({
    required String roomId,
    required String targetUserId,
    required String candidate,
  }) async {
    throw UnimplementedError(
      'VoiceSignalingService.publishIceCandidate (Etapa 5)',
    );
  }

  /// Stub: stream de mensagens de signaling endereçadas a mim.
  Stream<Map<String, dynamic>> watchSignalingForMe(String userId) {
    // Retorna stream vazio até a Etapa 5.
    return const Stream<Map<String, dynamic>>.empty();
  }
}

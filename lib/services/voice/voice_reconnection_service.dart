/// `VoiceReconnectionService` — detecta perda de rede e tenta
/// reconectar com backoff exponencial.
///
/// **STUB para Etapa 5**: nesta etapa apenas documenta a API
/// pretendida. A reconexão do LiveKit já existe por padrão
/// (`ConnectionStateChanged` para `reconnecting`/`connected`),
/// mas queremos uma camada de retry mais robusta que cancele
/// e reconecte do zero se a reconexão automática falhar.
import '../../core/network/connectivity_service.dart';

class VoiceReconnectionService {
  VoiceReconnectionService({ConnectivityService? connectivity})
      : _connectivity = connectivity ?? ConnectivityService();

  final ConnectivityService _connectivity;

  /// Stub: para a Etapa 5, este método monitora conectividade
  /// e tenta reconectar com backoff (1s, 2s, 4s, 8s, máximo 30s).
  Future<void> startWatching() async {
    // TODO(etapa-5): implementar backoff e retry.
  }

  Future<void> stopWatching() async {
    // TODO(etapa-5).
  }
}

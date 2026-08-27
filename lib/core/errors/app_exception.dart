/// Exceções específicas do aplicativo EROS.
///
/// Usa herança para categorizar erros por origem:
/// - [AuthException]: problemas de autenticação Firebase
/// - [FirestoreException]: falhas na comunicação com Firestore
/// - [NetworkException]: falta ou instabilidade de conexão
/// - [PermissionException]: permissão de sistema negada
/// - [VoiceException]: erros específicos de WebRTC/voz
///
/// Opcionalmente pode incluir código de erro do backend para tratamento
/// específico na UI (ex: mostrar mensagem diferente).
abstract class AppException implements Exception {
  const AppException({
    required this.message,
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Erros de autenticação (login, senha, token expirado, etc.)
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.stackTrace,
  });
}

/// Erros relacionados ao Firestore (permissão, quota, offline, etc.)
class FirestoreException extends AppException {
  const FirestoreException({
    required super.message,
    super.stackTrace,
  });
}

/// Erros de conexão de rede (sem internet, timeout, etc.)
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.stackTrace,
  });
}

/// Erros de permissão do sistema (microfone, notificação, storage, etc.)
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.stackTrace,
  });
}

/// Erros específicos de funcionalidade de voz (WebRTC, signaling, etc.)
class VoiceException extends AppException {
  const VoiceException({
    required super.message,
    super.stackTrace,
  });
}
/// Configuração de ambiente do aplicativo.
///
/// Carrega valores de configuração em tempo de compilação
/// (via `--dart-define`) com fallback para valores seguros
/// de desenvolvimento. Mantém o resto do código desacoplado
/// de chaves hard-coded.
class EnvConfig {
  EnvConfig._();

  /// Identificador do projeto Firebase.
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'eros-dev',
  );

  /// Chave de API do Firebase (lida do .env ou dart-define).
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  /// ID do app Firebase (mobile).
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  /// Sender ID do FCM.
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  /// Indica se o app está rodando em modo de desenvolvimento.
  static const bool isDev = bool.fromEnvironment(
    'DEV',
    defaultValue: true,
  );

  /// Nível mínimo de log para o logger interno.
  ///
  /// Em produção o logger deve ser silencioso para `info` e abaixo.
  static const String logLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'debug',
  );

  /// URL do servidor de token do LiveKit.
  ///
  /// Quando vazio, o `VoiceRoomService` entra em **modo de
  /// simulação** (mostra UI, não conecta áudio real). Permite
  /// testar o app em APK sem backend.
  static const String liveKitTokenServerUrl = String.fromEnvironment(
    'LIVEKIT_TOKEN_SERVER_URL',
    defaultValue: '',
  );

  /// URL do servidor LiveKit (wss://...).
  static const String liveKitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: '',
  );

  /// Flag de modo simulação para a sala de voz.
  /// Quando true, mesmo com token server ausente, a UI completa
  /// pode ser testada (sem áudio real).
  static const bool voiceStubMode = bool.fromEnvironment(
    'VOICE_STUB',
    defaultValue: true,
  );
}

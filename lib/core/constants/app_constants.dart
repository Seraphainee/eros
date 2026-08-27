/// Constantes globais do aplicativo EROS.
///
/// Centraliza valores fixos que não pertencem a nenhuma feature
/// específica: limites, timeouts, tamanhos, chaves de armazenamento local, etc.
class AppConstants {
  AppConstants._();

  // --- Storage keys (SharedPreferences) ---
  static const String kSessionUserIdKey = 'session_user_id';
  static const String kSessionUserEmailKey = 'session_user_email';
  static const String kSessionTokenKey = 'session_token';
  static const String kLastOpenedRouteKey = 'last_opened_route';

  // --- Timeouts ---
  static const Duration authTimeout = Duration(seconds: 30);
  static const Duration firestoreTimeout = Duration(seconds: 15);

  // --- Limites de conteúdo ---
  static const int maxMessageLength = 4096;
  static const int maxAttachmentSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxAttachmentsPerMessage = 10;

  // --- Rate limit ---
  static const int maxMessagesPerMinute = 30;

  // --- Presence ---
  static const Duration presenceHeartbeatInterval = Duration(seconds: 15);
  static const Duration userOfflineThreshold = Duration(seconds: 35);

  // --- Ranking ---
  static const int maxVoicePointsPerDay = 120; // 2h de voz/dia
  static const int maxMessagesForPointsPerHour = 60;
  static const Duration messagePointCooldown = Duration(seconds: 30);
}

/// Constantes para o sistema de ranking e níveis.
///
/// Contém curvas de progressão, pontuações e configurações antiabuso.
class RankingConstants {
  RankingConstants._();

  // --- Pontos por ação ---
  /// Pontos concedidos por minuto em sala de voz (com mais de 1 participante).
  static const int voicePointsPerMinute = 1;

  /// Pontos concedidos por mensagem enviada (sujeito a cooldown).
  static const int messagePoints = 2;

  /// Pontos bônus por participar de um evento de grupo.
  static const int eventBonusPoints = 50;

  // --- Limites antiabuso ---
  /// Máximo de minutos de voz que geram pontos por dia.
  static const int maxVoiceMinutesPerDay = 120;

  /// Máximo de mensagens pontuáveis por hora.
  static const int maxMessagesPerHour = 60;

  /// Cooldown mínimo entre mensagens que geram pontos (em segundos).
  static const int messagePointCooldownSeconds = 30;

  /// Tempo mínimo de participantes em sala para começar a pontuar (em segundos).
  /// Evita pontuar quando só 1 pessoa está na sala.
  static const int minParticipantsForVoicePoints = 2;

  // --- Níveis ---
  /// Pontos necessários para cada nível.
  /// Exemplo: nível 1 = 0 pts, nível 2 = 100 pts, nível 3 = 300 pts...
  static const List<int> levelThresholds = [
    0,       // nível 1
    100,     // nível 2
    300,     // nível 3
    600,     // nível 4
    1000,    // nível 5
    1500,    // nível 6
    2200,    // nível 7
    3100,    // nível 8
    4200,    // nível 9
    5500,    // nível 10
    7000,    // nível 11
    8800,    // nível 12
    11000,   // nível 13
    13500,   // nível 14
    16500,   // nível 15
  ];

  /// Retorna o nível correspondente a uma quantidade de pontos.
  static int levelForPoints(int points) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (points >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  /// Pontos necessários para o próximo nível (null se for nível máximo).
  static int? pointsToNextLevel(int points) {
    final current = levelForPoints(points);
    if (current >= levelThresholds.length) return null;
    return levelThresholds[current] - points;
  }

  /// Progresso (0.0 a 1.0) dentro do nível atual.
  static double progressInLevel(int points) {
    final current = levelForPoints(points);
    if (current >= levelThresholds.length) return 1.0;
    final start = levelThresholds[current - 1];
    final end = levelThresholds[current];
    return (points - start) / (end - start);
  }
}
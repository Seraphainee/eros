/// Constantes do sistema de XP de USUÁRIO (diferente do nível de
/// GRUPO em `ranking_constants.dart`, embora ambos usem a mesma
/// curva de níveis `RankingConstants.levelThresholds`).
///
/// Regra de negócio (confirmada pelo dono do produto):
/// - XP acumula apenas por TEMPO COM O APP ABERTO (qualquer tela,
///   não precisa estar em sala de voz).
/// - Usuário normal ganha a taxa base (1x).
/// - VIP ganha 4x a taxa base.
/// - VIP+ (tier acima) ganha 8x a taxa base.
/// - Uma sala específica pode ter seu próprio multiplicador de XP
///   (ex: "XP 8x" visto na referência) — pensado para ajudar quem
///   NÃO é VIP a compensar, então o multiplicador da sala se aplica
///   por cima do multiplicador de VIP (ver `XpService` para a
///   fórmula exata de composição).
class XpConstants {
  XpConstants._();

  /// Pontos de XP concedidos por minuto de app aberto, para um
  /// usuário sem VIP e fora de qualquer sala com multiplicador.
  static const int basePointsPerMinute = 1;

  /// Intervalo do heartbeat de XP (creditar pontos a cada N segundos
  /// de app aberto). Mais curto que o de presença porque XP precisa
  /// ser granular; mais longo que 1s para não gerar tráfego demais.
  static const int heartbeatIntervalSeconds = 60;

  /// Multiplicador por tier de VIP. `none` = usuário comum.
  static const Map<VipTier, int> vipMultiplier = <VipTier, int>{
    VipTier.none: 1,
    VipTier.vip: 4,
    VipTier.vipPlus: 8,
  };

  /// Multiplicador de XP de uma sala especial, quando não
  /// especificado no canal (ver `ChannelModel.xpMultiplier`).
  static const int defaultRoomMultiplier = 1;

  /// Multiplicador máximo permitido para uma sala (trava de
  /// segurança contra configuração errada gerando XP absurdo).
  static const int maxRoomMultiplier = 20;
}

/// Nível de assinatura VIP do usuário. Afeta o multiplicador de XP
/// (ver [XpConstants.vipMultiplier]) e pode futuramente afetar outros
/// benefícios (badges, cores de nome, etc. — fora do escopo desta
/// etapa).
enum VipTier {
  none,
  vip,
  vipPlus,
}
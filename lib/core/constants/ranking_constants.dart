/// Sistema de RANK + NÍVEL do usuário (diferente do nível de GRUPO em
/// `ranking_constants.dart`).
///
/// Estrutura: 11 RANKS (Coração, Gota, Diamante, Coroa, Escudo, Casa,
/// Estrela, Raio, Asa, Fênix, Coroa Real), cada um com 5 NÍVEIS —
/// totalizando 55 níveis de usuário.
///
/// A curva de XP ([levelThresholds]) foi derivada da tabela de tempo
/// "ÜCRETSİZ (Normal)" fornecida pelo dono do produto: tempo total
/// para completar cada rank inteiro (5 níveis), convertido para XP
/// usando a taxa base de `XpConstants.basePointsPerMinute` (1 XP/min
/// = 60 XP/hora), e distribuído em 5 fatias CRESCENTES dentro do
/// rank (progressão geométrica, razão 1.35 — cada nível custa mais
/// que o anterior). O nível 1 de cada rank começa exatamente onde o
/// rank anterior termina (custo 0 para "entrar" no rank).
///
/// PRO e ULTRA (VIP e VIP+) NÃO têm uma curva própria — eles sobem
/// mais rápido porque ganham XP em taxa maior (4x/8x, ver
/// `XpConstants.vipMultiplier`), não porque os thresholds mudam.
///
/// Ícones: artes customizadas em SVG (coração, gota, diamante, coroa,
/// escudo, casa, estrela, raio, asa, fênix, coroa real), uma por
/// nível (55 arquivos), em `assets/icons/ranks/`.
/// [RankConstants.iconAssetPathForLevel] monta o caminho do ícone de
/// um nível específico (1..55); [RankDefinition.iconFallback] é o
/// emoji usado como fallback caso o asset não carregue.
class RankConstants {
  RankConstants._();

  /// XP acumulado necessário para estar em cada um dos 55 níveis.
  /// Índice 0 = nível 1 (0 pts). Ver derivação completa no cabeçalho
  /// deste arquivo.
  static const List<int> levelThresholds = <int>[
    0, // nível 1 — Coração 1
    179, // nível 2 — Coração 2
    421, // nível 3 — Coração 3
    747, // nível 4 — Coração 4
    1188, // nível 5 — Coração 5
    1188, // nível 6 — Gota 1
    1644, // nível 7 — Gota 2
    2259, // nível 8 — Gota 3
    3090, // nível 9 — Gota 4
    4212, // nível 10 — Gota 5
    4212, // nível 11 — Diamante 1
    5319, // nível 12 — Diamante 2
    6814, // nível 13 — Diamante 3
    8832, // nível 14 — Diamante 4
    11556, // nível 15 — Diamante 5
    11556, // nível 16 — Coroa 1
    14313, // nível 17 — Coroa 2
    18035, // nível 18 — Coroa 3
    23060, // nível 19 — Coroa 4
    29844, // nível 20 — Coroa 5
    29844, // nível 21 — Escudo 1
    36704, // nível 22 — Escudo 2
    45966, // nível 23 — Escudo 3
    58469, // nível 24 — Escudo 4
    75348, // nível 25 — Escudo 5
    75348, // nível 26 — Casa 1
    92434, // nível 27 — Casa 2
    115500, // nível 28 — Casa 3
    146639, // nível 29 — Casa 4
    188676, // nível 30 — Casa 5
    188676, // nível 31 — Estrela 1
    231206, // nível 32 — Estrela 2
    288621, // nível 33 — Estrela 3
    366132, // nível 34 — Estrela 4
    470772, // nível 35 — Estrela 5
    470772, // nível 36 — Raio 1
    475064, // nível 37 — Raio 2
    480859, // nível 38 — Raio 3
    488681, // nível 39 — Raio 4
    499242, // nível 40 — Raio 5
    499242, // nível 41 — Asa 1
    510138, // nível 42 — Asa 2
    524847, // nível 43 — Asa 3
    544704, // nível 44 — Asa 4
    571512, // nível 45 — Asa 5
    571512, // nível 46 — Fênix 1
    598916, // nível 47 — Fênix 2
    635912, // nível 48 — Fênix 3
    685857, // nível 49 — Fênix 4
    753282, // nível 50 — Fênix 5
    753282, // nível 51 — Coroa Real 1
    821298, // nível 52 — Coroa Real 2
    913119, // nível 53 — Coroa Real 3
    1037078, // nível 54 — Coroa Real 4
    1204422, // nível 55 — Coroa Real 5
  ];

  /// Quantidade de níveis dentro de cada rank.
  static const int levelsPerRank = 5;

  /// Os 11 ranks, em ordem crescente. `slug` é o identificador usado
  /// no nome de arquivo dos ícones (ex.: `t01_coracao`).
  static const List<RankDefinition> ranks = <RankDefinition>[
    RankDefinition(name: 'Coração', iconFallback: '❤️', slug: 't01_coracao'),
    RankDefinition(name: 'Gota', iconFallback: '💧', slug: 't02_gota'),
    RankDefinition(name: 'Diamante', iconFallback: '💎', slug: 't03_diamante'),
    RankDefinition(name: 'Coroa', iconFallback: '👑', slug: 't04_coroa'),
    RankDefinition(name: 'Escudo', iconFallback: '🛡️', slug: 't05_escudo'),
    RankDefinition(name: 'Casa', iconFallback: '🏠', slug: 't06_casa'),
    RankDefinition(name: 'Estrela', iconFallback: '⭐', slug: 't07_estrela'),
    RankDefinition(name: 'Raio', iconFallback: '⚡', slug: 't08_raio'),
    RankDefinition(name: 'Asa', iconFallback: '🪽', slug: 't09_asa'),
    RankDefinition(name: 'Fênix', iconFallback: '🔥', slug: 't10_fenix'),
    RankDefinition(name: 'Coroa Real', iconFallback: '👑', slug: 't11_coroa_real'),
  ];

  /// Caminho do asset SVG do ícone de um nível específico (1..55),
  /// ex.: `assets/icons/ranks/nivel_07_t02_gota.svg`.
  static String iconAssetPathForLevel(int level) {
    final clamped = level.clamp(1, levelThresholds.length);
    final slug = rankForLevel(clamped).slug;
    final levelStr = clamped.toString().padLeft(2, '0');
    return 'assets/icons/ranks/nivel_${levelStr}_$slug.svg';
  }

  /// Nível (1..55) correspondente a uma quantidade de pontos de XP.
  static int levelForXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  /// Índice do rank (0..10) correspondente a um nível (1..55).
  static int rankIndexForLevel(int level) {
    final clamped = level.clamp(1, levelThresholds.length);
    return ((clamped - 1) ~/ levelsPerRank).clamp(0, ranks.length - 1);
  }

  /// Nível dentro do rank (1..5) correspondente a um nível global (1..55).
  static int levelWithinRank(int level) {
    final clamped = level.clamp(1, levelThresholds.length);
    return ((clamped - 1) % levelsPerRank) + 1;
  }

  /// Definição do rank correspondente a um nível global (1..55).
  static RankDefinition rankForLevel(int level) => ranks[rankIndexForLevel(level)];

  /// XP necessário para o próximo nível (null se já no nível máximo).
  static int? xpToNextLevel(int xp) {
    final current = levelForXp(xp);
    if (current >= levelThresholds.length) return null;
    return levelThresholds[current] - xp;
  }

  /// Progresso (0.0 a 1.0) dentro do nível atual.
  static double progressInLevel(int xp) {
    final current = levelForXp(xp);
    if (current >= levelThresholds.length) return 1.0;
    final start = levelThresholds[current - 1];
    final end = levelThresholds[current];
    if (end == start) return 1.0; // evita divisão por zero (níveis com custo 0)
    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }
}

/// Definição visual de um rank (grupo de 5 níveis).
class RankDefinition {
  const RankDefinition({
    required this.name,
    required this.iconFallback,
    required this.slug,
  });

  /// Nome do rank (ex: "Coroa Real").
  final String name;

  /// Emoji usado como fallback caso o asset SVG não carregue.
  final String iconFallback;

  /// Identificador do tema usado no nome de arquivo do ícone
  /// (ex.: `t02_gota`). Use [RankConstants.iconAssetPathForLevel]
  /// para montar o caminho completo de um nível específico.
  final String slug;
}
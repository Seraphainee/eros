/// Sistema de RANK + NÍVEL do usuário (diferente do nível de GRUPO em
/// `ranking_constants.dart`).
///
/// Estrutura: 11 RANKS (Coração, Diamante, Coroa Prata, Coroa Ouro,
/// Coroa Azul, Coroa Colorida, Coroa c/ Fita, Coroa Rosa/Dourada,
/// Coroa Verde, Coroa Vermelha, Troféu), cada um com 5 NÍVEIS —
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
/// Ícones: a referência usa artes customizadas (coração, diamante,
/// coroas coloridas, troféu) que ainda não foram fornecidas como
/// arquivo. [RankDefinition.iconAssetPath] já aponta para onde elas
/// devem ficar quando chegarem; [RankDefinition.iconFallback] é o
/// emoji usado enquanto isso.
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
    1188, // nível 6 — Diamante 1
    1644, // nível 7 — Diamante 2
    2259, // nível 8 — Diamante 3
    3090, // nível 9 — Diamante 4
    4212, // nível 10 — Diamante 5
    4212, // nível 11 — Coroa Prata 1
    5319, // nível 12 — Coroa Prata 2
    6814, // nível 13 — Coroa Prata 3
    8832, // nível 14 — Coroa Prata 4
    11556, // nível 15 — Coroa Prata 5
    11556, // nível 16 — Coroa Ouro 1
    14313, // nível 17 — Coroa Ouro 2
    18035, // nível 18 — Coroa Ouro 3
    23060, // nível 19 — Coroa Ouro 4
    29844, // nível 20 — Coroa Ouro 5
    29844, // nível 21 — Coroa Azul 1
    36704, // nível 22 — Coroa Azul 2
    45966, // nível 23 — Coroa Azul 3
    58469, // nível 24 — Coroa Azul 4
    75348, // nível 25 — Coroa Azul 5
    75348, // nível 26 — Coroa Colorida 1
    92434, // nível 27 — Coroa Colorida 2
    115500, // nível 28 — Coroa Colorida 3
    146639, // nível 29 — Coroa Colorida 4
    188676, // nível 30 — Coroa Colorida 5
    188676, // nível 31 — Coroa c/ Fita 1
    231206, // nível 32 — Coroa c/ Fita 2
    288621, // nível 33 — Coroa c/ Fita 3
    366132, // nível 34 — Coroa c/ Fita 4
    470772, // nível 35 — Coroa c/ Fita 5
    470772, // nível 36 — Coroa Rosa/Dourada 1
    475064, // nível 37 — Coroa Rosa/Dourada 2
    480859, // nível 38 — Coroa Rosa/Dourada 3
    488681, // nível 39 — Coroa Rosa/Dourada 4
    499242, // nível 40 — Coroa Rosa/Dourada 5
    499242, // nível 41 — Coroa Verde 1
    510138, // nível 42 — Coroa Verde 2
    524847, // nível 43 — Coroa Verde 3
    544704, // nível 44 — Coroa Verde 4
    571512, // nível 45 — Coroa Verde 5
    571512, // nível 46 — Coroa Vermelha 1
    598916, // nível 47 — Coroa Vermelha 2
    635912, // nível 48 — Coroa Vermelha 3
    685857, // nível 49 — Coroa Vermelha 4
    753282, // nível 50 — Coroa Vermelha 5
    753282, // nível 51 — Troféu 1
    821298, // nível 52 — Troféu 2
    913119, // nível 53 — Troféu 3
    1037078, // nível 54 — Troféu 4
    1204422, // nível 55 — Troféu 5
  ];

  /// Quantidade de níveis dentro de cada rank.
  static const int levelsPerRank = 5;

  /// Os 11 ranks, em ordem crescente.
  static const List<RankDefinition> ranks = <RankDefinition>[
    RankDefinition(name: 'Coração', iconFallback: '❤️', iconAssetPath: 'assets/ranks/heart.png'),
    RankDefinition(name: 'Diamante', iconFallback: '💎', iconAssetPath: 'assets/ranks/diamond.png'),
    RankDefinition(name: 'Coroa Prata', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_silver.png'),
    RankDefinition(name: 'Coroa Ouro', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_gold.png'),
    RankDefinition(name: 'Coroa Azul', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_blue.png'),
    RankDefinition(name: 'Coroa Colorida', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_colorful.png'),
    RankDefinition(name: 'Coroa com Fita', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_ribbon.png'),
    RankDefinition(name: 'Coroa Rosa/Dourada', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_pink_gold.png'),
    RankDefinition(name: 'Coroa Verde', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_green.png'),
    RankDefinition(name: 'Coroa Vermelha', iconFallback: '👑', iconAssetPath: 'assets/ranks/crown_red.png'),
    RankDefinition(name: 'Troféu', iconFallback: '🏆', iconAssetPath: 'assets/ranks/trophy.png'),
  ];

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
    required this.iconAssetPath,
  });

  /// Nome do rank (ex: "Coroa Azul").
  final String name;

  /// Emoji usado enquanto o asset customizado não é fornecido.
  final String iconFallback;

  /// Caminho esperado do asset customizado (ainda não existe no
  /// projeto — adicionar ao `pubspec.yaml` em `assets:` quando os
  /// arquivos PNG/SVG forem fornecidos).
  final String iconAssetPath;
}
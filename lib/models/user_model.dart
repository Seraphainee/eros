/// Modelo de dados para User (Firebase Auth + perfil adicional).
///
/// Usado tanto pelo auth_service (fonte de verdade da sessão) quanto
/// pelo profile_service (Firestore).
///
/// Implementação manual imutável nesta Etapa 1; quando o gerador
/// `freezed`/`json_serializable` for executado (Etapa 2), este arquivo
/// será migrado para a forma gerada preservando a mesma API pública.
import '../core/constants/rank_constants.dart';
import '../core/constants/xp_constants.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.birthDate,
    this.avatarUrl,
    this.signature,
    this.bio,
    required this.status,
    required this.createdAt,
    this.xpPoints = 0,
    this.vipTier = VipTier.none,
  });

  /// UID do Firebase Auth — chave primária.
  final String uid;

  /// E-mail (pode ser vazio se o login foi por provedor de terceiros sem e-mail).
  final String email;

  /// Nome de usuário escolhido pelo usuário (único, tipo @handle).
  final String username;

  /// Nome de exibição (nome completo/apelido, separado do username).
  final String? displayName;

  /// Data de nascimento informada no cadastro (usada para checagem de idade
  /// mínima — não é reexibida publicamente no perfil).
  final DateTime? birthDate;

  /// URL do avatar (pode ser null até que seja carregado).
  ///
  /// TODO: upload real ainda não implementado — depende de
  /// `avatar_upload_service.dart` + `firebase_storage` (a definir
  /// em etapa futura). Por enquanto este campo só é lido/gravado
  /// como texto (URL) quando já existir.
  final String? avatarUrl;

  /// Assinatura curta exibida logo abaixo do nome no perfil
  /// (equivalente a uma "bio de uma linha").
  final String? signature;

  /// Descrição longa ("Sobre") exibida na tela de perfil.
  final String? bio;

  /// Estado do usuário (online, offline, inRoom, etc.).
  final UserStatus status;

  /// Quando o perfil foi criado (Firestore).
  final DateTime createdAt;

  /// XP acumulado do usuário. Cresce apenas por tempo com o app
  /// aberto (ver `XpService`), multiplicado por [vipTier] e por um
  /// eventual multiplicador de sala. Alimenta [level], [rank] etc.
  /// via `RankConstants` (11 ranks x 5 níveis = 55 níveis).
  final int xpPoints;

  /// Tier de assinatura VIP do usuário — afeta a taxa de ganho de XP.
  final VipTier vipTier;

  /// Nível atual (1..55), derivado de [xpPoints].
  int get level => RankConstants.levelForXp(xpPoints);

  /// Rank atual (Coração, Diamante, ... Troféu), derivado de [level].
  RankDefinition get rank => RankConstants.rankForLevel(level);

  /// Nível dentro do rank atual (1..5).
  int get levelWithinRank => RankConstants.levelWithinRank(level);

  /// XP que falta para o próximo nível (null se nível máximo).
  int? get xpToNextLevel => RankConstants.xpToNextLevel(xpPoints);

  /// Progresso (0.0..1.0) dentro do nível atual.
  double get levelProgress => RankConstants.progressInLevel(xpPoints);

  /// Multiplicador de XP concedido pelo tier VIP do usuário.
  int get vipXpMultiplier => XpConstants.vipMultiplier[vipTier] ?? 1;

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    DateTime? birthDate,
    String? avatarUrl,
    String? signature,
    String? bio,
    UserStatus? status,
    DateTime? createdAt,
    int? xpPoints,
    VipTier? vipTier,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      signature: signature ?? this.signature,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      xpPoints: xpPoints ?? this.xpPoints,
      vipTier: vipTier ?? this.vipTier,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'birthDate': birthDate?.toIso8601String(),
        'avatarUrl': avatarUrl,
        'signature': signature,
        'bio': bio,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'xpPoints': xpPoints,
        'vipTier': vipTier.name,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        birthDate: json['birthDate'] == null
            ? null
            : DateTime.parse(json['birthDate'] as String),
        avatarUrl: json['avatarUrl'] as String?,
        signature: json['signature'] as String?,
        bio: json['bio'] as String?,
        status: UserStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => UserStatus.offline,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        xpPoints: (json['xpPoints'] as int?) ?? 0,
        vipTier: VipTier.values.firstWhere(
          (e) => e.name == json['vipTier'],
          orElse: () => VipTier.none,
        ),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.username == username &&
        other.displayName == displayName &&
        other.birthDate == birthDate &&
        other.avatarUrl == avatarUrl &&
        other.signature == signature &&
        other.bio == bio &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.xpPoints == xpPoints &&
        other.vipTier == vipTier;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        username,
        displayName,
        birthDate,
        avatarUrl,
        signature,
        bio,
        status,
        createdAt,
        xpPoints,
        vipTier,
      );

  @override
  String toString() =>
      'UserModel(uid: $uid, username: $username, status: $status, level: $level, xp: $xpPoints)';
}

/// Estados possíveis para um usuário no app.
enum UserStatus {
  offline,
  online,
  inRoom,
  away,
}
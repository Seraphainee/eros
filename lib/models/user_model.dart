/// Modelo de dados para User (Firebase Auth + perfil adicional).
///
/// Usado tanto pelo auth_service (fonte de verdade da sessão) quanto
/// pelo profile_service (Firestore).
///
/// Implementação manual imutável nesta Etapa 1; quando o gerador
/// `freezed`/`json_serializable` for executado (Etapa 2), este arquivo
/// será migrado para a forma gerada preservando a mesma API pública.
class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.birthDate,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
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
  final String? avatarUrl;

  /// Estado do usuário (online, offline, inRoom, etc.).
  final UserStatus status;

  /// Quando o perfil foi criado (Firestore).
  final DateTime createdAt;

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    DateTime? birthDate,
    String? avatarUrl,
    UserStatus? status,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'birthDate': birthDate?.toIso8601String(),
        'avatarUrl': avatarUrl,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
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
        status: UserStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => UserStatus.offline,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
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
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        username,
        displayName,
        birthDate,
        avatarUrl,
        status,
        createdAt,
      );

  @override
  String toString() => 'UserModel(uid: $uid, username: $username, status: $status)';
}

/// Estados possíveis para um usuário no app.
enum UserStatus {
  offline,
  online,
  inRoom,
  away,
}
/// `ProfileService` — CRUD do perfil público do usuário.
///
/// Responsabilidades:
/// - Garantir que `users/{uid}` exista (criado no primeiro acesso,
///   já que `AuthService.signUp` hoje só cria o esqueleto no
///   Firebase Auth, sem gravar Firestore — ver TODO em auth_service.dart).
/// - Ler/observar o perfil.
/// - Atualizar campos editáveis (nome de exibição, assinatura, bio,
///   avatarUrl).
///
/// Coleção tocada: `users/{userId}`.
///
/// TODO: upload de avatar (`avatar_upload_service.dart` +
/// `firebase_storage`) ainda não foi implementado. `updateAvatarUrl`
/// já existe aqui como ponto de entrada para quando o upload for
/// plugado — por enquanto ele só grava a URL recebida como texto.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Garante que o documento de perfil exista. Se não existir, cria
  /// a partir do [fallback] (montado pelo AuthService a partir do
  /// Firebase Auth). Se já existir, apenas retorna o que está salvo.
  Future<UserModel> ensureProfile(UserModel fallback) async {
    final ref = _usersRef.doc(fallback.uid);
    try {
      final snap = await ref.get();
      if (snap.exists && snap.data() != null) {
        return UserModel.fromJson(<String, dynamic>{
          ...snap.data()!,
          'uid': snap.id,
        });
      }
      await ref.set(fallback.toJson());
      Logger.i('ProfileService: perfil criado para ${fallback.uid}');
      return fallback;
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream do perfil de um usuário.
  Stream<UserModel?> watchProfile(String userId) {
    return _usersRef.doc(userId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromJson(<String, dynamic>{
        ...snap.data()!,
        'uid': snap.id,
      });
    }).handleError((error, st) {
      throw FirestoreException(message: error.toString(), stackTrace: st);
    });
  }

  /// Leitura única do perfil.
  Future<UserModel?> getProfile(String userId) async {
    try {
      final snap = await _usersRef.doc(userId).get();
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromJson(<String, dynamic>{
        ...snap.data()!,
        'uid': snap.id,
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Atualiza os campos editáveis do perfil.
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? signature,
    String? bio,
  }) async {
    if (displayName != null) {
      final error = Validators.validateDisplayName(displayName);
      if (error != null) {
        throw AuthException(message: 'invalid-display-name: $error');
      }
    }
    final signatureError = Validators.validateSignature(signature);
    if (signatureError != null) {
      throw AuthException(message: 'invalid-signature: $signatureError');
    }
    final bioError = Validators.validateBio(bio);
    if (bioError != null) {
      throw AuthException(message: 'invalid-bio: $bioError');
    }

    final updates = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (signature != null) 'signature': signature,
      if (bio != null) 'bio': bio,
    };
    if (updates.isEmpty) return;

    try {
      await _usersRef.doc(userId).update(updates);
      Logger.i('ProfileService: perfil atualizado $userId');
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Atualiza a URL do avatar.
  ///
  /// TODO: hoje recebe a URL já pronta (texto). Quando
  /// `avatar_upload_service.dart` existir, o fluxo será: escolher
  /// imagem -> subir para `firebase_storage` -> chamar este método
  /// com a URL resultante.
  Future<void> updateAvatarUrl({
    required String userId,
    required String? avatarUrl,
  }) async {
    try {
      await _usersRef.doc(userId).update(<String, dynamic>{
        'avatarUrl': avatarUrl,
      });
      Logger.i('ProfileService: avatar atualizado $userId');
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }
}
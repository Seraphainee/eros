/// Serviço de autenticação — fachada para o resto do app.
///
/// Combina:
/// - [AuthRepository]: chamadas ao Firebase Auth;
/// - [SessionManager]: persistência local da sessão.
///
/// É o único ponto de entrada que o restante do app (providers,
/// telas) deve usar para autenticar. Ele cuida de:
/// - persistir o token após login;
/// - limpar a sessão ao deslogar;
/// - propagar o `AuthState` para quem estiver ouvindo.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/user_model.dart';
import 'auth_repository.dart';
import 'session_manager.dart';

class AuthService {
  AuthService({
    required AuthRepository authRepository,
    required SessionManager sessionManager,
  })  : _repository = authRepository,
        _session = sessionManager {
    _authSub = _repository.onAuthStateChange.listen(_onRepositoryChange);
  }

  final AuthRepository _repository;
  final SessionManager _session;
  late final StreamSubscription<AuthState> _authSub;

  Stream<AuthState> get onAuthStateChange => _repository.onAuthStateChange;
  bool get isAuthenticated => _repository.currentState.isAuthenticated;
  String? get currentUserId => _session.currentUserId;

  /// Fluxo de login completo: autentica no Firebase e grava a sessão.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(message: 'no-user-after-sign-in');
      }
      final token = await user.getIdToken();
      await _session.startSession(
        userId: user.uid,
        email: user.email ?? email,
        token: token ?? '',
      );
      return _toUserModel(user);
    } on AuthException {
      rethrow;
    } catch (e, st) {
      Logger.e('AuthService.signIn falhou', stackTrace: st);
      throw AuthException(message: e.toString(), stackTrace: st);
    }
  }

  /// Cadastro: cria a conta, persiste a sessão e devolve o usuário.
  ///
  /// A criação do documento de perfil em `users/{uid}` é responsabilidade
  /// de um serviço de Profile posterior (Etapa 2). Aqui garantimos
  /// apenas o esqueleto da conta.
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
    DateTime? birthDate,
  }) async {
    try {
      final credential = await _repository.signUpWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(message: 'no-user-after-sign-up');
      }

      // Atualiza o displayName para que o Firebase Auth já tenha o nome
      // de exibição escolhido (fallback pro username se não informado).
      await user.updateDisplayName(displayName ?? username);

      final token = await user.getIdToken();
      await _session.startSession(
        userId: user.uid,
        email: user.email ?? email,
        token: token ?? '',
      );
      return _toUserModel(
        user,
        usernameOverride: username,
        displayNameOverride: displayName,
        birthDate: birthDate,
      );
    } on AuthException {
      rethrow;
    } catch (e, st) {
      Logger.e('AuthService.signUp falhou', stackTrace: st);
      throw AuthException(message: e.toString(), stackTrace: st);
    }
  }

  /// Logout: encerra a sessão no Firebase e remove a sessão local.
  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } finally {
      await _session.clear();
    }
  }

  /// Recuperação de senha (apenas Firebase — não cria sessão).
  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email: email);

  /// Atualiza a senha do usuário atual.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _repository.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Atualiza o token persistido após refresh.
  Future<void> refreshSessionToken() async {
    final token = await _repository.getIdToken(forceRefresh: true);
    if (token != null) {
      await _session.updateToken(token);
    }
  }

  Future<void> _onRepositoryChange(AuthState state) async {
    // Quando o Firebase encerra a sessão (ex: token inválido), refletimos
    // no SessionManager para evitar inconsistência com a UI.
    if (!state.isAuthenticated && _session.hasSession) {
      Logger.w('AuthService: Firebase deslogou o usuário — limpando sessão local.');
      await _session.clear();
    } else if (state.isAuthenticated && !_session.hasSession) {
      // Sessão do Firebase mas sem local (cold start com cache).
      final user = state.user;
      if (user != null) {
        final token = await user.getIdToken();
        await _session.startSession(
          userId: user.uid,
          email: user.email ?? '',
          token: token ?? '',
        );
      }
    }
  }

  UserModel _toUserModel(
    fb.User user, {
    String? usernameOverride,
    String? displayNameOverride,
    DateTime? birthDate,
  }) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      username: usernameOverride ?? user.displayName ?? user.email?.split('@').first ?? 'user',
      displayName: displayNameOverride ?? user.displayName,
      birthDate: birthDate,
      avatarUrl: user.photoURL,
      status: UserStatus.online,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  Future<void> dispose() async {
    await _authSub.cancel();
    await _session.dispose();
    await _repository.dispose();
  }
}
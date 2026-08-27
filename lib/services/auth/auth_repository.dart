/// Repositório de autenticação do Firebase.
///
/// Camada fina em cima de `firebase_auth` que:
/// - converte `FirebaseAuthException` em `AuthException` (do app);
/// - expõe streams de estado de autenticação;
/// - centraliza o tratamento de credenciais e provedores.
///
/// Esta classe não conhece `SessionManager` nem Firestore —
/// mantém-se pura para ser testável isoladamente.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';

/// Snapshot de autenticação observado por listeners.
class AuthState {
  const AuthState({this.user, this.isLoading = false});

  /// Usuário Firebase atual (pode ser `null` quando deslogado).
  final fb.User? user;

  /// Verdadeiro durante transições de login/logout.
  final bool isLoading;

  bool get isAuthenticated => user != null;
}

class AuthRepository {
  AuthRepository({fb.FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? fb.FirebaseAuth.instance {
    _subscription = _auth.authStateChanges().listen(_handleAuthChange);
  }

  final fb.FirebaseAuth _auth;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  late final StreamSubscription<fb.User?> _subscription;
  AuthState _lastState = const AuthState();

  Stream<AuthState> get onAuthStateChange => _controller.stream;
  AuthState get currentState => _lastState;
  fb.User? get currentUser => _lastState.user;

  void _handleAuthChange(fb.User? user) {
    _lastState = AuthState(user: user);
    Logger.i('AuthRepository: authState -> ${user?.uid ?? "null"}');
    _controller.add(_lastState);
  }

  /// Realiza login com e-mail e senha.
  Future<fb.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _emitLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on fb.FirebaseAuthException catch (e, st) {
      throw AuthException(message: e.code, stackTrace: st);
    } finally {
      _emitLoading(false);
    }
  }

  /// Cria uma nova conta de e-mail/senha.
  Future<fb.UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _emitLoading(true);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on fb.FirebaseAuthException catch (e, st) {
      throw AuthException(message: e.code, stackTrace: st);
    } finally {
      _emitLoading(false);
    }
  }

  /// Envia e-mail de recuperação de senha.
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e, st) {
      throw AuthException(message: e.code, stackTrace: st);
    }
  }

  /// Faz logout.
  Future<void> signOut() async {
    try {
      _emitLoading(true);
      await _auth.signOut();
    } on fb.FirebaseAuthException catch (e, st) {
      throw AuthException(message: e.code, stackTrace: st);
    } finally {
      _emitLoading(false);
    }
  }

  /// Atualiza a senha do usuário atual (re-autenticação externa).
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'no-current-user');
    }
    try {
      final credential = fb.EmailAuthProvider.credential(
        email: user.email ?? '',
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e, st) {
      throw AuthException(message: e.code, stackTrace: st);
    }
  }

  /// Retorna o token de acesso atual (refresh se expirado).
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  void _emitLoading(bool loading) {
    _lastState = AuthState(user: _lastState.user, isLoading: loading);
    _controller.add(_lastState);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}

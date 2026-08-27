/// Provider Riverpod para o serviço de autenticação.
///
/// Mantém o [AuthService] como singleton no escopo da aplicação
/// e expõe seu estado para a UI em forma de [AsyncValue].
///
/// A árvore de providers segue a convenção:
/// - `authServiceProvider` -> dependência injetada manualmente no
///   `app.dart` (após o bootstrap).
/// - `authStateProvider`  -> estado observável (loading/user/erro).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../models/user_model.dart';
import '../services/auth/auth_repository.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/session_manager.dart';

/// Provider base — é sobrescrito em `app.dart` após o bootstrap.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError(
    'authServiceProvider deve ser sobrescrito no ProviderScope da raiz.',
  );
});

/// Estado da UI de autenticação.
class AuthUiState {
  const AuthUiState({
    required this.isLoading,
    required this.user,
    required this.errorMessage,
  });

  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  static const AuthUiState initial = AuthUiState(
    isLoading: true,
    user: null,
    errorMessage: null,
  );

  AuthUiState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthUiState> {
  AuthController(this._service) : super(AuthUiState.initial) {
    _sub = _service.onAuthStateChange.listen(_onAuthStateChange);
  }

  final AuthService _service;
  late final StreamSubscription<AuthState> _sub;

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signIn(email: email, password: password);
      state = AuthUiState(isLoading: false, user: user, errorMessage: null);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      Logger.w('AuthController.signIn falhou: ${e.message}');
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signUp(
        email: email,
        password: password,
        username: username,
      );
      state = AuthUiState(isLoading: false, user: user, errorMessage: null);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      Logger.w('AuthController.signUp falhou: ${e.message}');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.signOut();
      state = const AuthUiState(
        isLoading: false,
        user: null,
        errorMessage: null,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    }
  }

  Future<void> recoverPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.sendPasswordReset(email);
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    }
  }

  void _onAuthStateChange(AuthState authState) {
    if (authState.isLoading) {
      state = state.copyWith(isLoading: true);
      return;
    }
    if (authState.user == null) {
      state = const AuthUiState(
        isLoading: false,
        user: null,
        errorMessage: null,
      );
    }
    // Caso o usuário esteja presente, o carregamento do perfil completo
    // é responsabilidade do profileService (Etapa 2). Aqui só refletimos
    // o estado de autenticação.
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<AuthController, AuthUiState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});

/// Acesso de conveniência ao ID do usuário autenticado.
final Provider<String?> currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.user?.uid;
});

/// Helper para o `SessionManager` reagir a logout (ex: limpar cache local).
final Provider<SessionManager> sessionManagerProvider =
    Provider<SessionManager>((ref) {
  throw UnimplementedError(
    'sessionManagerProvider deve ser sobrescrito no ProviderScope da raiz.',
  );
});

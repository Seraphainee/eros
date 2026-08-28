/// Gerenciador de sessão persistente do usuário.
///
/// Mantém, entre execuções do app, o ID do usuário autenticado
/// e o token do Firebase Auth no `SharedPreferences` (criptografado
/// em produção por meio das APIs nativas de keystore — a interface
/// aqui permanece simples para a Etapa 1).
///
/// Esta classe é o único ponto que lê/escreve os tokens
/// de autenticação. Services e providers consultam a sessão
/// ativa através de `currentUserId()` e `currentToken()`.
import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  SessionManager(this._prefs);

  final SharedPreferences _prefs;

  final StreamController<SessionEvent> _events =
      StreamController<SessionEvent>.broadcast();

  /// Stream de eventos de sessão (login/logout/restaurado).
  Stream<SessionEvent> get events => _events.stream;

  /// UID do usuário atualmente autenticado, ou `null` se anônimo.
  String? get currentUserId => _prefs.getString(AppConstants.kSessionUserIdKey);

  /// E-mail salvo localmente, útil para exibir na UI antes do refresh
  /// do perfil Firestore.
  String? get currentUserEmail =>
      _prefs.getString(AppConstants.kSessionUserEmailKey);

  /// Token do Firebase Auth (refresh token usado em reautenticação).
  String? get currentToken => _prefs.getString(AppConstants.kSessionTokenKey);

  /// Indica se existe uma sessão persistida.
  bool get hasSession =>
      (currentUserId ?? '').isNotEmpty && (currentToken ?? '').isNotEmpty;

  /// Indica se o usuário marcou "Lembrar login" na última vez que logou.
  bool get rememberLoginEnabled =>
      _prefs.getBool(AppConstants.kRememberLoginKey) ?? false;

  /// E-mail lembrado para pré-preencher a tela de login após logout.
  /// Só é relevante quando [rememberLoginEnabled] é true — nunca guarda
  /// a senha, apenas o e-mail, por segurança.
  String? get rememberedEmail =>
      _prefs.getString(AppConstants.kRememberedEmailKey);

  /// Persiste a sessão recém-criada.
  Future<void> startSession({
    required String userId,
    required String email,
    required String token,
  }) async {
    await _prefs.setString(AppConstants.kSessionUserIdKey, userId);
    await _prefs.setString(AppConstants.kSessionUserEmailKey, email);
    await _prefs.setString(AppConstants.kSessionTokenKey, token);
    Logger.i('SessionManager: sessão iniciada para uid=$userId');
    _events.add(SessionEvent.started(userId));
  }

  /// Salva a preferência de "Lembrar login" e o e-mail associado.
  ///
  /// Quando [remember] é false, apaga qualquer e-mail lembrado
  /// anteriormente (a pessoa optou por não ser lembrada).
  Future<void> setRememberLogin({
    required bool remember,
    required String email,
  }) async {
    await _prefs.setBool(AppConstants.kRememberLoginKey, remember);
    if (remember) {
      await _prefs.setString(AppConstants.kRememberedEmailKey, email);
    } else {
      await _prefs.remove(AppConstants.kRememberedEmailKey);
    }
  }

  /// Atualiza apenas o token (refresh periódico).
  Future<void> updateToken(String token) async {
    await _prefs.setString(AppConstants.kSessionTokenKey, token);
  }

  /// Limpa qualquer vestígio da sessão anterior.
  ///
  /// Mantém o e-mail lembrado (se [rememberLoginEnabled] estiver ativo)
  /// para pré-preencher a tela de login — apenas a sessão ativa é
  /// encerrada, não a preferência de "Lembrar login".
  Future<void> clear() async {
    final previousId = currentUserId;
    await _prefs.remove(AppConstants.kSessionUserIdKey);
    await _prefs.remove(AppConstants.kSessionUserEmailKey);
    await _prefs.remove(AppConstants.kSessionTokenKey);
    if (previousId != null) {
      Logger.i('SessionManager: sessão encerrada para uid=$previousId');
      _events.add(SessionEvent.ended(previousId));
    }
  }

  Future<void> dispose() async {
    await _events.close();
  }
}

/// Eventos emitidos pelo [SessionManager].
class SessionEvent {
  const SessionEvent._(this.type, this.userId);

  factory SessionEvent.started(String userId) =>
      SessionEvent._(SessionEventType.started, userId);

  factory SessionEvent.ended(String userId) =>
      SessionEvent._(SessionEventType.ended, userId);

  final SessionEventType type;
  final String userId;
}

enum SessionEventType { started, ended }
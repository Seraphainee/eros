/// Handler centralizado de erros do aplicativo.
///
/// Converte exceções em mensagens de UI amigáveis e realiza
/// logging adequado para debugging.
import 'package:flutter/material.dart';
import 'app_exception.dart';
import '../utils/logger.dart';

class ErrorHandler {
  ErrorHandler._();

  /// Mensagem amigável para o usuário final, baseada no tipo de exceção.
  static String getUserMessage(AppException exception) {
    return switch (exception) {
      AuthException() => _handleAuthException(exception),
      FirestoreException() => _handleFirestoreException(exception),
      NetworkException() => _handleNetworkException(exception),
      PermissionException() => _handlePermissionException(exception),
      VoiceException() => _handleVoiceException(exception),
      AppException() => 'Ocorreu um erro inesperado. Tente novamente.',
    };
  }

  static String _handleAuthException(AuthException e) {
    return switch (e.message.toLowerCase()) {
      'invalid-email' || 'invalid_email' => 'E-mail inválido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'user-not-found' => 'Usuário não encontrado.',
      'wrong-password' => 'Senha incorreta.',
      'too-many-requests' => 'Muitas tentativas. Tente novamente mais tarde.',
      'network-request-error' => 'Sem conexão com a internet.',
      _ => 'Erro de autenticação. Tente novamente.',
    };
  }

  static String _handleFirestoreException(FirestoreException e) {
    return switch (e.message.toLowerCase()) {
      'permission-denied' => 'Acesso negado. Você não tem permissão para esta ação.',
      'unavailable' => 'Serviço temporariamente indisponível. Tente novamente.',
      'deadline-exceeded' => 'Operação demorou muito tempo. Tente novamente.',
      _ => 'Falha ao carregar os dados. Tente novamente.',
    };
  }

  static String _handleNetworkException(NetworkException e) {
    return 'Conexão com a internet interrompida. Verifique sua rede.';
  }

  static String _handlePermissionException(PermissionException e) {
    return e.message;
  }

  static String _handleVoiceException(VoiceException e) {
    return 'Problema com áudio/voz. Verifique as permissões e conexão.';
  }

  /// Exibe um SnackBar com a mensagem apropriada.
  static void showSnackBar(BuildContext context, AppException exception) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getUserMessage(exception)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Loga o erro para debug e analytics.
  static void logError(AppException exception, {String? tag}) {
    Logger.e(
      'AppException [$tag]: ${exception.message}',
      stackTrace: exception.stackTrace,
    );
  }
}
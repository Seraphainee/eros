/// Logger customizado que encapsula o pacote logger.
///
/// Fornece um wrapper simples para controle de níveis
/// e formatação de mensagens de log.
import 'package:logger/logger.dart' as ext;
import 'package:flutter/foundation.dart';

class Logger {
  Logger._();

  static final ext.Logger _logger = ext.Logger(
    printer: ext.PrettyPrinter(
      methodCount: 0,
      colors: true,
      printEmojis: true,
    ),
    filter: ext.DevelopmentFilter(),
  );

  /// Mensagem de debug (apenas em modo desenvolvimento).
  static void d(String message, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, stackTrace: stackTrace);
    }
  }

  /// Mensagem informativa.
  static void i(String message, {StackTrace? stackTrace}) {
    _logger.i(message, stackTrace: stackTrace);
  }

  /// Mensagem de aviso.
  static void w(String message, {StackTrace? stackTrace}) {
    _logger.w(message, stackTrace: stackTrace);
  }

  /// Mensagem de erro.
  static void e(String message, {StackTrace? stackTrace}) {
    _logger.e(message, stackTrace: stackTrace);
  }

  /// Mensagem de erro crítica.
  static void wtf(String message, {StackTrace? stackTrace}) {
    _logger.wtf(message, stackTrace: stackTrace);
  }
}

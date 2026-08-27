/// Platform Channel para notificações nativas.
///
/// Gerencia ações de notificação (clique em ação, dismiss, etc.)
/// e o canal de push notifications via Firebase Cloud Messaging.
import 'package:flutter/services.dart';

abstract class NotificationPlatformChannel {
  static const _channel = MethodChannel('eros.app/notification_channel');

  /// Solicita permissão de notificação no Android 13+.
  static Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Indica se notificações estão habilitadas nas configurações do app.
  static Future<bool> areNotificationsEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Abre as configurações de notificação do sistema para o app.
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      // Falha silenciosa — apenas não abre as configurações.
    }
  }

  /// Cancela todas as notificações do app.
  static Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
    } on PlatformException {
      // Falha silenciosa.
    }
  }
}
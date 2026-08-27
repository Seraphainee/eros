/// `VoicePermissionService` — pede e checa permissões de mic
/// e notificação antes de entrar em uma sala de voz.
///
/// Permissões necessárias:
/// - `RECORD_AUDIO` (Android, iOS) — microfone.
/// - `POST_NOTIFICATIONS` (Android 13+) — notificação persistente
///   do VoiceForegroundService.
///
/// Retorna resultado estruturado para a UI mostrar mensagens
/// específicas ("permita mic nas configurações", etc).
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/app_exception.dart';
import '../../core/platform/notification_platform_channel.dart';

enum VoicePermissionResult {
  granted,
  micDenied,
  notificationDenied,
  micPermanentlyDenied,
  notificationPermanentlyDenied,
}

class VoicePermissionService {
  VoicePermissionService();

  /// Pede mic e (Android 13+) permissão de notificação.
  ///
  /// Retorna o `granted` apenas se TODAS as permissões foram
  /// concedidas. Permanece parcialmente denegado se uma for.
  Future<VoicePermissionResult> requestAll() async {
    // Mic
    final micStatus = await Permission.microphone.request();
    if (micStatus.isPermanentlyDenied) {
      return VoicePermissionResult.micPermanentlyDenied;
    }
    if (!micStatus.isGranted) {
      return VoicePermissionResult.micDenied;
    }

    // Notificação (Android 13+). Em versões mais antigas é
    // granted por default; permission_handler trata isso.
    final notifGranted = await NotificationPlatformChannel.requestPermission();
    if (!notifGranted) {
      // O canal nativo retorna `false` para permanentemente denied
      // e para "ainda não pediu" — distinguir requer consulta de
      // status. Para esta etapa, devolvemos "denied" e deixamos
      // a UI pedir de novo.
      return VoicePermissionResult.notificationDenied;
    }

    return VoicePermissionResult.granted;
  }

  /// Verifica se todas as permissões já estão concedidas
  /// (sem pedir).
  Future<bool> hasAll() async {
    final mic = await Permission.microphone.isGranted;
    if (!mic) return false;
    final notifEnabled =
        await NotificationPlatformChannel.areNotificationsEnabled();
    return notifEnabled;
  }

  /// Helper para abrir configurações do app quando o usuário
  /// marcou "não perguntar de novo".
  Future<bool> openSettings() => openAppSettings();

  /// Converte um [VoicePermissionResult] em mensagem amigável
  /// para a UI.
  String messageFor(VoicePermissionResult result) {
    switch (result) {
      case VoicePermissionResult.granted:
        return 'Permissões concedidas.';
      case VoicePermissionResult.micDenied:
        return 'Permissão de microfone negada.';
      case VoicePermissionResult.notificationDenied:
        return 'Permissão de notificação negada.';
      case VoicePermissionResult.micPermanentlyDenied:
        return 'Permissão de microfone bloqueada. Abra as configurações do app para permitir.';
      case VoicePermissionResult.notificationPermanentlyDenied:
        return 'Notificações bloqueadas. Abra as configurações do app para permitir.';
    }
  }

  /// Lança [PermissionException] se o resultado não for granted.
  void assertGranted(VoicePermissionResult result) {
    if (result != VoicePermissionResult.granted) {
      throw PermissionException(message: messageFor(result));
    }
  }
}

/// Platform Channel para comunicação com o VoiceForegroundService do Android.
///
/// Conecta o Flutter ao serviço nativo Kotlin de voz em segundo plano.
/// Permite iniciar/interromper o serviço, atualizar notificação, e
/// consultar estado sem耦ar a Activity.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../errors/app_exception.dart';

/// Métodos expostos pelo canal.
abstract class VoicePlatformChannel {
  static const _channel = MethodChannel('eros.app/voice_channel');

  /// Inicia o VoiceForegroundService com os dados da sala.
  static Future<void> startVoiceService({
    required String roomId,
    required String roomName,
    required bool isMuted,
  }) async {
    try {
      await _channel.invokeMethod('startVoiceService', {
        'roomId': roomId,
        'roomName': roomName,
        'isMuted': isMuted,
      });
    } on PlatformException catch (e, st) {
      throw VoiceException(
        message: e.message ?? 'Falha ao iniciar serviço de voz.',
        stackTrace: st,
      );
    }
  }

  /// Para e destrói o VoiceForegroundService.
  static Future<void> stopVoiceService() async {
    try {
      await _channel.invokeMethod('stopVoiceService');
    } on PlatformException catch (e, st) {
      throw VoiceException(
        message: e.message ?? 'Falha ao parar serviço de voz.',
        stackTrace: st,
      );
    }
  }

  /// Atualiza o estado de mudo na notificação persistente.
  static Future<void> updateMuteState({required bool isMuted}) async {
    try {
      await _channel.invokeMethod('updateMuteState', {'isMuted': isMuted});
    } on PlatformException catch (e, st) {
      debugPrint('updateMuteState failed: ${e.message}');
    }
  }

  /// Stream de eventos nativos -> Flutter (EventChannel).
  static const _eventChannel = EventChannel('eros.app/voice_events');

  static Stream<Map<String, dynamic>> get voiceEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
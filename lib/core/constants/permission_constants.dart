/// Permissões de sistema utilizadas pelo app EROS.
///
/// Centraliza as permissões Android/iOS e seus motivos explicativos.
import 'package:permission_handler/permission_handler.dart';

class PermissionConstants {
  PermissionConstants._();

  // Permissões necessárias para a funcionalidade de voz
  static final Map<Permission, String> requiredForVoice = {
    Permission.microphone: 'Permissão para captar áudio durante chamadas de voz.',
    Permission.notification: 'Permissão para mostrar notificação persistente durante chamadas em segundo plano.',
    Permission.storage: 'Permissão para acessar arquivos de áudio (se aplicável).',
  };

  // Permissões necessárias para carregar avatar
  static final Map<Permission, String> requiredForProfile = {
    Permission.storage: 'Permissão para escolher imagem do perfil.',
    Permission.photos: 'Permissão para acessar galeria de fotos.',
  };

  // Permissões básicas do app
  static final Set<Permission> basicPermissions = {
    Permission.notification,
  };

  /// Verifica se todas as permissões estão concedidas.
  static Future<bool> allGranted(Set<Permission> permissions) async {
    for (final p in permissions) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  /// Solicita permissões que ainda não foram concedidas.
  static Future<Map<Permission, PermissionStatus>> requestMissing(
    Set<Permission> permissions,
  ) async {
    final toRequest = permissions.where((p) => !await p.isGranted).toSet();
    if (toRequest.isEmpty) return {};
    return await toRequest.request();
  }
}
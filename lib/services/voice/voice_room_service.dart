/// `VoiceRoomService` — orquestrador da sala de voz.
///
/// Combina:
/// - `WebRtcClient` (wrapper de `livekit_client.Room`).
/// - `VoicePermissionService` (mic + notificação).
/// - `VoiceSignalingService` (stub para Etapa 5).
/// - `VoiceReconnectionService` (stub para Etapa 5).
/// - `VoicePlatformChannel` (foreground service Android).
///
/// Fluxo `connect`:
/// 1. Pede permissões (mic + notificação).
/// 2. Pede token ao backend (HTTP).
/// 3. Chama `WebRtcClient.connect(url, token)`.
/// 4. Aciona o `VoiceForegroundService` no Android via
///    `VoicePlatformChannel.startVoiceService`.
/// 5. Inicia a tentativa de reconexão (stub nesta etapa).
///
/// Fluxo `disconnect`:
/// 1. Para o foreground service.
/// 2. `WebRtcClient.disconnect()`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/platform/voice_platform_channel.dart';
import '../../models/voice_room_state_model.dart';
import '../channels/channel_permission_service.dart';
import '../permissions/permission_resolver.dart';
import 'voice_permission_service.dart';
import 'voice_reconnection_service.dart';
import 'voice_signaling_service.dart';
import 'webrtc_client.dart';

class VoiceRoomService {
  VoiceRoomService({
    WebRtcClient? webrtcClient,
    VoicePermissionService? permissionService,
    VoiceSignalingService? signalingService,
    VoiceReconnectionService? reconnectionService,
    ChannelPermissionService? channelPermissionService,
    PermissionResolver? permissionResolver,
    http.Client? httpClient,
    fb.FirebaseAuth? firebaseAuth,
    String? tokenServerUrl,
    String? liveKitUrl,
  })  : _webrtc = webrtcClient ?? WebRtcClient(),
        _permissions = permissionService ?? VoicePermissionService(),
        _signaling = signalingService ?? VoiceSignalingService(),
        _reconnection = reconnectionService ?? VoiceReconnectionService(),
        _channelPermission =
            channelPermissionService ?? ChannelPermissionService(),
        _resolver = permissionResolver ?? PermissionResolver(),
        _http = httpClient ?? http.Client(),
        _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _tokenServerUrl = tokenServerUrl,
        _liveKitUrl = liveKitUrl;

  final WebRtcClient _webrtc;
  final VoicePermissionService _permissions;
  final VoiceSignalingService _signaling;
  final VoiceReconnectionService _reconnection;
  final ChannelPermissionService _channelPermission;
  final PermissionResolver _resolver;
  final http.Client _http;
  final fb.FirebaseAuth _auth;
  final String? _tokenServerUrl;
  final String? _liveKitUrl;

  Stream<VoiceRoomState> get state => _webrtc.state;
  VoiceRoomState get currentState => _webrtc.currentState;
  bool get isMuted => _webrtc.isMuted;

  /// Acesso ao cliente WebRTC (usado pelo stub para delegar
  /// a conexão).
  WebRtcClient get webrtcClient => _webrtc;

  /// Entra em uma sala de voz.
  Future<void> connect({
    required String groupId,
    required String channelId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'not-authenticated');
    }
    final userId = user.uid;

    // 1. Permissões.
    final permResult = await _permissions.requestAll();
    if (permResult != VoicePermissionResult.granted) {
      throw PermissionException(message: _permissions.messageFor(permResult));
    }

    // 2. Checagem de permissão de falar.
    final canSpeak = await _channelPermission.canSpeakInVoice(
      groupId: groupId,
      channelId: channelId,
      userId: userId,
    );
    if (!canSpeak) {
      throw const AuthException(message: 'no-speak-permission');
    }

    // 3. Token.
    if (_tokenServerUrl == null || _liveKitUrl == null) {
      throw const VoiceException(
        message: 'livekit-not-configured: defina tokenServerUrl e liveKitUrl',
      );
    }
    final token = await _fetchToken(
      groupId: groupId,
      channelId: channelId,
      userId: userId,
    );

    // 4. Conexão WebRTC.
    await _webrtc.connect(
      url: _liveKitUrl!,
      token: token,
      channelId: channelId,
    );

    // 5. Foreground service Android.
    try {
      await VoicePlatformChannel.startVoiceService(
        roomId: channelId,
        roomName: 'Sala de voz',
        isMuted: _webrtc.isMuted,
      );
    } on VoiceException catch (e) {
      // Não fatal: o usuário pode usar a sala sem foreground service
      // em foreground. Loga e segue.
      Logger.w('VoiceRoomService: foreground service falhou (${e.message})');
    }

    // 6. Reconnection watcher (stub).
    await _reconnection.startWatching();

    Logger.i('VoiceRoomService: entrou em $channelId (grupo $groupId)');
  }

  /// Sai da sala.
  Future<void> disconnect() async {
    try {
      await VoicePlatformChannel.stopVoiceService();
    } catch (e) {
      Logger.w('VoiceRoomService: stopVoiceService falhou: $e');
    }
    await _reconnection.stopWatching();
    await _webrtc.disconnect();
    Logger.i('VoiceRoomService: saiu da sala');
  }

  /// Muta/desmuta mic.
  Future<void> setMuted(bool muted) async {
    await _webrtc.setMuted(muted);
    try {
      await VoicePlatformChannel.updateMuteState(isMuted: muted);
    } catch (_) {
      // best-effort
    }
  }

  Future<String> _fetchToken({
    required String groupId,
    required String channelId,
    required String userId,
  }) async {
    final user = _auth.currentUser!;
    final idToken = await user.getIdToken();
    try {
      final response = await _http.post(
        Uri.parse('$_tokenServerUrl/livekit/token'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(<String, String>{
          'groupId': groupId,
          'channelId': channelId,
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw VoiceException(
          message: 'token-server-error: ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['token'] as String;
    } on VoiceException {
      rethrow;
    } catch (e, st) {
      throw VoiceException(
        message: 'token-fetch-failed: $e',
        stackTrace: st,
      );
    }
  }

  Future<String> _loadGroupOwnerId(String groupId) async {
    // Reaproveita a implementação do ChannelPermissionService.
    return _channelPermission
        .canManageChannels(groupId: groupId, userId: '__probe__')
        .then((_) => '__probe__')
        // _ownerId é privado; no lugar, usamos a doc de group.
        .catchError((_) => '')
        .then((_) async {
      // Workaround: delega ao _channelPermission que já busca owner.
      // Aqui simplesmente retornamos o owner via o mesmo serviço.
      // Para evitar expor método privado, a POC faz uma busca direta.
      return groupId; // simplificado para a POC
    });
  }

  Future<void> dispose() async {
    await disconnect();
    await _webrtc.dispose();
    _http.close();
  }
}

// Bit espelhado (corresponde a `PermissionKeys.speakInVoice`).
const int _speakInVoice = 1 << 4;

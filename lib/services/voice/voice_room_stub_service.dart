/// `VoiceRoomServiceStub` — implementação stub do [VoiceRoomService]
/// usada quando o `EnvConfig.voiceStubMode` é `true` (default em dev).
///
/// **NÃO conecta ao LiveKit, NÃO usa microfone, NÃO exibe
/// notificação persistente.** Mas mantém a mesma interface do
/// serviço real, então a UI funciona 100% — incluindo o overlay
/// flutuante e os estados visuais.
///
/// Use para:
/// - Testes de UI no APK sem backend.
/// - Demonstrações para stakeholders.
/// - Testes manuais de fluxo (entrar/sair, mute, reconexão, etc).
///
/// Implementação: herda de [VoiceRoomService] e sobrescreve apenas
/// [connect] para pular permissões, checagem de falar e token
/// server, delegando ao [StubWebRtcClient] (que emite o estado
/// fake).
library;

import 'dart:async';
import 'dart:math';

import '../../core/platform/voice_platform_channel.dart';
import '../../core/utils/logger.dart';
import '../../models/voice_participant_model.dart';
import '../../models/voice_room_state_model.dart';
import 'voice_room_service.dart';
import 'webrtc_client.dart';

/// Participantes fake para a UI.
const List<Map<String, String>> _stubParticipants = <Map<String, String>>[
  <String, String>{'id': 'u1', 'name': 'Alice'},
  <String, String>{'id': 'u2', 'name': 'Bruno'},
  <String, String>{'id': 'u3', 'name': 'Carla'},
  <String, String>{'id': 'u4', 'name': 'Diego'},
  <String, String>{'id': 'u5', 'name': 'Elena'},
];

/// `WebRtcClient` stub: finge estar conectado, emite participantes
/// fake e simula indicador de fala ativa.
class StubWebRtcClient implements WebRtcClient {
  final StreamController<VoiceRoomState> _stateController =
      StreamController<VoiceRoomState>.broadcast();
  VoiceRoomState _state = VoiceRoomState.initial;
  Timer? _speakerTimer;
  bool _isMuted = false;
  final Random _random = Random(42);
  final List<VoiceParticipantModel> _stubList = _stubParticipants
      .map(
        (p) => VoiceParticipantModel(
          userId: 'stub-${p['id']!}',
          displayName: p['name']!,
          photoUrl: null,
          isMuted: true,
          isSpeaking: false,
          isLocal: false,
          joinedAt: DateTime.now(),
        ),
      )
      .toList();

  @override
  Stream<VoiceRoomState> get state => _stateController.stream;

  @override
  VoiceRoomState get currentState => _state;

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String channelId,
  }) async {
    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.connecting,
      channelId: channelId,
      clearError: true,
    ));

    await Future<void>.delayed(const Duration(milliseconds: 800));

    final local = VoiceParticipantModel(
      userId: 'stub-local',
      displayName: 'Você',
      photoUrl: null,
      isMuted: _isMuted,
      isSpeaking: false,
      isLocal: true,
      joinedAt: DateTime.now(),
    );

    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.connected,
      channelId: channelId,
      participants: <VoiceParticipantModel>[..._stubList, local],
    ));

    _startSpeakerSimulation();
  }

  @override
  Future<void> disconnect() async {
    _speakerTimer?.cancel();
    _emit(VoiceRoomState.initial.copyWith(clearChannel: true));
  }

  @override
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    final updated = _state.participants.map((p) {
      if (p.isLocal) return p.copyWith(isMuted: muted);
      return p;
    }).toList();
    _emit(_state.copyWith(participants: updated));
  }

  void _startSpeakerSimulation() {
    _speakerTimer?.cancel();
    _speakerTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_state.participants.isEmpty) return;
      final updated = <VoiceParticipantModel>[];
      for (final p in _state.participants) {
        if (p.isLocal) {
          updated.add(p.copyWith(isSpeaking: false));
          continue;
        }
        final willSpeak = _random.nextDouble() < 0.25;
        updated.add(p.copyWith(
          isSpeaking: willSpeak,
          isMuted: willSpeak ? false : (p.isMuted || _random.nextDouble() < 0.3),
        ));
      }
      _emit(_state.copyWith(participants: updated));
    });
  }

  void _emit(VoiceRoomState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  @override
  Future<void> dispose() async {
    _speakerTimer?.cancel();
    await _stateController.close();
  }
}

/// `VoiceRoomService` stub: herda do real mas sobrescreve `connect`
/// para pular permissões/canSpeak/token (o [StubWebRtcClient] é
/// autônomo).
class VoiceRoomServiceStub extends VoiceRoomService {
  VoiceRoomServiceStub({required String liveKitUrl, required String tokenServerUrl})
      : _liveKitUrl = liveKitUrl,
        _tokenServerUrl = tokenServerUrl,
        super(
          webrtcClient: StubWebRtcClient(),
          liveKitUrl: liveKitUrl,
          tokenServerUrl: tokenServerUrl,
        );

  final String _liveKitUrl;
  final String _tokenServerUrl;

  /// Constrói a partir de [EnvConfig].
  static VoiceRoomService create({
    required String liveKitUrl,
    required String tokenServerUrl,
  }) {
    Logger.i(
      'VoiceRoomServiceStub: usando liveKitUrl=$liveKitUrl, '
      'tokenServerUrl=${tokenServerUrl.isEmpty ? "(vazio)" : tokenServerUrl}',
    );
    return VoiceRoomServiceStub(
      liveKitUrl: liveKitUrl,
      tokenServerUrl: tokenServerUrl,
    );
  }

  @override
  Future<void> connect({
    required String groupId,
    required String channelId,
  }) async {
    Logger.i('VoiceRoomServiceStub.connect: $channelId (stub mode)');
    // Pula permissões, canSpeak e token — apenas delega ao WebRtcClient mock.
    await webrtcClient.connect(
      url: _liveKitUrl,
      token: 'stub-token',
      channelId: channelId,
    );
    // Tenta iniciar foreground service (best-effort, falha silenciosa
    // quando o canal nativo não responde).
    try {
      await VoicePlatformChannel.startVoiceService(
        roomId: channelId,
        roomName: 'Sala de voz (stub)',
        isMuted: webrtcClient.isMuted,
      );
    } catch (e) {
      Logger.w('VoiceRoomServiceStub: foreground service pulado: $e');
    }
    Logger.i('VoiceRoomServiceStub: entrou em $channelId (stub)');
  }
}

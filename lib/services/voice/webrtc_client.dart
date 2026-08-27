/// `WebRtcClient` — wrapper sobre `livekit_client.Room`.
///
/// Garante que o resto do app não importe `livekit_client`
/// diretamente (a interface exposta usa apenas os nossos models).
///
/// POC (Etapa 4). Eventos cobertos:
/// - ParticipantConnected / ParticipantDisconnected
/// - ActiveSpeakersChanged
/// - ConnectionStateChanged
/// - RoomDisconnected
///
/// Eventos de track (TrackSubscribed/Unsubscribed) ficam para Etapa 5.
import 'dart:async';

import 'package:livekit_client/livekit_client.dart' as lk;

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/voice_participant_model.dart';
import '../../models/voice_room_state_model.dart';

class WebRtcClient {
  WebRtcClient();

  lk.Room? _room;
  final List<Function> _listenerCancels = [];
  final StreamController<VoiceRoomState> _stateController =
      StreamController<VoiceRoomState>.broadcast();
  VoiceRoomState _state = VoiceRoomState.initial;

  Stream<VoiceRoomState> get state => _stateController.stream;
  VoiceRoomState get currentState => _state;

  /// Conecta a uma sala LiveKit.
  ///
  /// - `url`: `wss://livekit.example.com` (ws ou wss).
  /// - `token`: JWT assinado pelo token server.
  /// - `channelId`: usado como `roomId` e metadata.
  Future<void> connect({
    required String url,
    required String token,
    required String channelId,
  }) async {
    if (_room != null) {
      throw const VoiceException(message: 'already-connected');
    }
    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.connecting,
      channelId: channelId,
      clearError: true,
    ));

    final room = lk.Room();

    // Registra listeners.
    _listenerCancels.add(
      room.events.on<lk.ParticipantConnectedEvent>(_onParticipantConnected),
    );
    _listenerCancels.add(
      room.events.on<lk.ParticipantDisconnectedEvent>(_onParticipantDisconnected),
    );
    _listenerCancels.add(
      room.events.on<lk.ActiveSpeakersChangedEvent>(_onActiveSpeakersChanged),
    );
    _listenerCancels.add(
      room.events.on<lk.RoomReconnectingEvent>(_onRoomReconnecting),
    );
    _listenerCancels.add(
      room.events.on<lk.RoomConnectedEvent>(_onRoomConnected),
    );
    _listenerCancels.add(
      room.events.on<lk.RoomDisconnectedEvent>(_onRoomDisconnected),
    );
    _listenerCancels.add(
      room.events.on<lk.TrackSubscribedEvent>(_onTrackSubscribed),
    );
    _listenerCancels.add(
      room.events.on<lk.TrackUnsubscribedEvent>(_onTrackUnsubscribed),
    );

    try {
      await room.prepareConnection(url, token);
      await room.connect(url, token);
      // Habilita microfone por padrão.
      await room.localParticipant?.setMicrophoneEnabled(true);
      _room = room;
      _refreshParticipants();
      _emit(_state.copyWith(
        connectionState: VoiceConnectionState.connected,
      ));
      Logger.i('WebRtcClient: conectado em $url (channel=$channelId)');
    } catch (e, st) {
      _emit(_state.copyWith(
        connectionState: VoiceConnectionState.failed,
        errorMessage: e.toString(),
        clearChannel: true,
      ));
      throw VoiceException(message: e.toString(), stackTrace: st);
    }
  }

  /// Desconecta da sala.
  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;
    try {
      await room.disconnect();
    } catch (e, st) {
      Logger.w('WebRtcClient.disconnect erro: $e', stackTrace: st);
    } finally {
      for (final cancel in _listenerCancels) {
        await cancel();
      }
      _listenerCancels.clear();
      _room = null;
      _emit(_state.copyWith(
        connectionState: VoiceConnectionState.disconnected,
        participants: const <VoiceParticipantModel>[],
        clearChannel: true,
      ));
    }
  }

  /// Muta ou desmutar o microfone local.
  Future<void> setMuted(bool muted) async {
    final room = _room;
    if (room == null) return;
    try {
      await room.localParticipant?.setMicrophoneEnabled(!muted);
      _refreshParticipants();
    } catch (e, st) {
      Logger.w('WebRtcClient.setMuted falhou: $e', stackTrace: st);
    }
  }

  bool get isConnected => _room != null;

  bool get isMuted {
    final room = _room;
    if (room == null) return true;
    // TODO(etapa-4): verificar getter real do livekit_client.
    return false;
  }

  // --- Event handlers ---

  void _onParticipantConnected(lk.ParticipantConnectedEvent event) {
    Logger.i('WebRtcClient: participante entrou ${event.participant.identity}');
    _refreshParticipants();
  }

  void _onParticipantDisconnected(lk.ParticipantDisconnectedEvent event) {
    Logger.i('WebRtcClient: participante saiu ${event.participant.identity}');
    _refreshParticipants();
  }

  void _onActiveSpeakersChanged(lk.ActiveSpeakersChangedEvent event) {
    _refreshParticipants();
  }

  void _onTrackSubscribed(lk.TrackSubscribedEvent event) {
    Logger.d('WebRtcClient: track subscribed ${event.publication.kind}');
    // Áudio é tocado automaticamente pelo LiveKit.
  }

  void _onTrackUnsubscribed(lk.TrackUnsubscribedEvent event) {
    Logger.d('WebRtcClient: track unsubscribed ${event.publication.kind}');
  }

  void _onRoomReconnecting(lk.RoomReconnectingEvent event) {
    Logger.d('WebRtcClient: room reconnecting');
    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.reconnecting,
    ));
  }

  void _onRoomConnected(lk.RoomConnectedEvent event) {
    Logger.d('WebRtcClient: room connected');
    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.connected,
    ));
  }

  void _onRoomDisconnected(lk.RoomDisconnectedEvent event) {
    Logger.w('WebRtcClient: room disconnected (reason=${event.reason})');
    _room = null;
    for (final cancel in _listenerCancels) {
      cancel();
    }
    _listenerCancels.clear();
    _emit(_state.copyWith(
      connectionState: VoiceConnectionState.disconnected,
      participants: const <VoiceParticipantModel>[],
      clearChannel: true,
    ));
  }

  void _refreshParticipants() {
    final room = _room;
    if (room == null) return;
    final list = <VoiceParticipantModel>[];
    for (final p in room.remoteParticipants.values) {
      list.add(_toModel(p, isLocal: false));
    }
    final local = room.localParticipant;
    if (local != null) {
      list.add(_toModel(local, isLocal: true));
    }
    _emit(_state.copyWith(participants: list));
  }

  VoiceParticipantModel _toModel(lk.Participant p, {required bool isLocal}) {
    // TODO(etapa-4): verificar propriedades exatas do livekit_client.
    // livekit_client 2.x expõe `identity`, `name`, `isSpeaking`,
    // e os tracks. `joinedAt` pode não existir no SDK — fallback para
    // `DateTime.now()`.
    final name = (p as dynamic).name as String? ?? p.identity;
    return VoiceParticipantModel(
      userId: p.identity,
      displayName: name.isNotEmpty ? name : p.identity,
      photoUrl: null,
      isMuted: !(p.isMicrophoneEnabled()),
      isSpeaking: p.isSpeaking,
      isLocal: isLocal,
      joinedAt: DateTime.now(),
    );
  }

  void _emit(VoiceRoomState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }
}

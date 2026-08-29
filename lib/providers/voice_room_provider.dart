/// Providers Riverpod para a sala de voz.
///
/// Estado:
/// - `voiceRoomServiceProvider` — service singleton (injetado via override
///   no `app.dart`).
/// - `voiceRoomStateStreamProvider` — stream de estado por canal.
/// - `voiceRoomControllerProvider` — `StateNotifier` com ações
///   (`connect` / `disconnect` / `setMuted`).
/// - `voiceRoomUiStateProvider` — estado de UI (carregando entrada, erro,
///   mic em transição).
/// - `presenceServiceProvider` — presença em Firestore (contagem de
///   pessoas por canal, visível mesmo para quem não está na chamada).
/// - `channelPresenceProvider` — stream de userIds presentes num canal.
///
/// A `VoiceRoomScreen` consome o stream e o controller. A
/// `GroupDetailScreen` consome `channelPresenceProvider` para mostrar
/// a contagem "N" ao lado de cada canal de voz.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../models/voice_room_state_model.dart';
import '../providers/auth_provider.dart';
import '../services/presence/presence_service.dart';
import '../services/voice/voice_room_service.dart';

/// Service da sala de voz.
///
/// Aceita configuração opcional (tokenServerUrl, liveKitUrl) que
/// deve ser injetada via override no `app.dart` (Etapa 5 define
/// o contrato de configuração).
final Provider<VoiceRoomService> voiceRoomServiceProvider =
    Provider<VoiceRoomService>((ref) {
  return VoiceRoomService();
});

/// Service de presença (Firestore) — singleton compartilhado.
final Provider<PresenceService> presenceServiceProvider =
    Provider<PresenceService>((ref) {
  return PresenceService();
});

/// Stream do estado de uma sala por `channelId`.
final StreamProviderFamily<VoiceRoomState, String>
    voiceRoomStateStreamProvider =
    StreamProvider.family<VoiceRoomState, String>((ref, channelId) {
  final service = ref.watch(voiceRoomServiceProvider);
  // Re-emit do estado atual + mudanças futuras.
  return service.state
      .where((s) => s.channelId == channelId || s.channelId == null)
      .distinct();
});

/// Stream dos `userId` presentes (não-stale) num canal de voz.
/// Fonte usada pela `GroupDetailScreen` para mostrar contagem e
/// avatares de quem está no canal, mesmo sem estar conectado nele.
final StreamProviderFamily<List<String>, String> channelPresenceProvider =
    StreamProvider.family<List<String>, String>((ref, channelId) {
  return ref.watch(presenceServiceProvider).watchChannelPresence(channelId);
});

/// Stream de quantos membros de um grupo estão online agora.
/// Usado no badge "N Online" do card do servidor.
final StreamProviderFamily<int, String> groupOnlineCountProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  return ref.watch(presenceServiceProvider).watchGroupOnlineCount(groupId);
});

/// Estado de UI da sala de voz (separado do estado técnico do WebRTC).
class VoiceRoomUiState {
  const VoiceRoomUiState({
    this.isEntering = false,
    this.isMuteTogglePending = false,
    this.errorMessage,
  });

  /// True enquanto o `connect` está em andamento.
  final bool isEntering;

  /// True enquanto `setMuted` está em andamento (debounce de UI).
  final bool isMuteTogglePending;

  /// Mensagem de erro fatal (ex: permissão negada, token falhou).
  /// Diferente do `errorMessage` no `VoiceRoomState` (que é o erro
  /// técnico do LiveKit).
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  VoiceRoomUiState copyWith({
    bool? isEntering,
    bool? isMuteTogglePending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceRoomUiState(
      isEntering: isEntering ?? this.isEntering,
      isMuteTogglePending: isMuteTogglePending ?? this.isMuteTogglePending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoiceRoomController extends StateNotifier<VoiceRoomUiState> {
  VoiceRoomController(this._service, this._presence, this._ref)
      : super(const VoiceRoomUiState());

  final VoiceRoomService _service;
  final PresenceService _presence;
  final Ref _ref;
  Timer? _heartbeatTimer;

  /// Entra na sala. Idempotente: se já está conectado em outro
  /// canal, desconecta antes. Também registra presença no Firestore
  /// (visível para quem não está na chamada) e inicia o heartbeat.
  Future<void> connect({
    required String groupId,
    required String channelId,
  }) async {
    if (state.isEntering) return;
    state = state.copyWith(isEntering: true, clearError: true);
    try {
      // Se já estamos em outra sala, desconecta primeiro.
      if (_service.currentState.isInRoom &&
          _service.currentState.channelId != channelId) {
        await _service.disconnect();
        _stopHeartbeat();
      }
      await _service.connect(groupId: groupId, channelId: channelId);
      state = state.copyWith(isEntering: false);

      final uid = _ref.read(currentUserIdProvider);
      if (uid != null) {
        await _presence.joinVoiceChannel(
          userId: uid,
          groupId: groupId,
          channelId: channelId,
        );
        _startHeartbeat(uid);
      }
    } on AppException catch (e) {
      Logger.w('VoiceRoomController.connect: ${e.message}');
      state = state.copyWith(isEntering: false, errorMessage: e.message);
    } catch (e) {
      Logger.w('VoiceRoomController.connect falhou: $e');
      state = state.copyWith(
        isEntering: false,
        errorMessage: 'Falha ao entrar: $e',
      );
    }
  }

  /// Sai da sala (acionado pelo botão "Desconectar" explícito).
  /// O back do sistema NÃO chama isto — ele só minimiza a tela.
  Future<void> disconnect() async {
    try {
      await _service.disconnect();
      _stopHeartbeat();
      final uid = _ref.read(currentUserIdProvider);
      if (uid != null) {
        await _presence.leaveVoiceChannel(uid);
      }
    } catch (e) {
      Logger.w('VoiceRoomController.disconnect: $e');
    } finally {
      state = state.copyWith(isMuteTogglePending: false, clearError: true);
    }
  }

  /// Muta/desmuta o microfone.
  Future<void> setMuted(bool muted) async {
    if (state.isMuteTogglePending) return;
    state = state.copyWith(isMuteTogglePending: true);
    try {
      await _service.setMuted(muted);
    } catch (e) {
      Logger.w('VoiceRoomController.setMuted($muted): $e');
    } finally {
      if (mounted) {
        state = state.copyWith(isMuteTogglePending: false);
      }
    }
  }

  /// Limpa o erro de UI (ex: após exibir snackbar).
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Mantém `lastSeen` fresco no Firestore a cada 20s enquanto
  /// conectado, para que outros usuários continuem vendo a
  /// contagem correta sem depender de um processo de servidor.
  void _startHeartbeat(String uid) {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _presence.heartbeat(uid);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    super.dispose();
  }
}

final StateNotifierProvider<VoiceRoomController, VoiceRoomUiState>
    voiceRoomControllerProvider =
    StateNotifierProvider<VoiceRoomController, VoiceRoomUiState>((ref) {
  return VoiceRoomController(
    ref.watch(voiceRoomServiceProvider),
    ref.watch(presenceServiceProvider),
    ref,
  );
});
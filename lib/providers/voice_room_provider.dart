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
///
/// A `VoiceRoomScreen` consome o stream e o controller.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../models/voice_room_state_model.dart';
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
  VoiceRoomController(this._service) : super(const VoiceRoomUiState());

  final VoiceRoomService _service;

  /// Entra na sala. Idempotente: se já está conectado em outro
  /// canal, desconecta antes.
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
      }
      await _service.connect(groupId: groupId, channelId: channelId);
      state = state.copyWith(isEntering: false);
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
}

final StateNotifierProvider<VoiceRoomController, VoiceRoomUiState>
    voiceRoomControllerProvider =
    StateNotifierProvider<VoiceRoomController, VoiceRoomUiState>((ref) {
  return VoiceRoomController(ref.watch(voiceRoomServiceProvider));
});

/// `VoiceRoomScreen` — tela de sala de voz ativa.
///
/// Layout:
/// - AppBar com nome do canal + `ConnectionStatusBadge` + botão sair.
/// - Body: lista de `ParticipantTile` (avatar + nome + mic).
/// - Footer: `MicControlButton` (mute/desmute) + indicador de contagem.
///
/// Back do sistema: não desconecta (apenas pop). Para encerrar
/// a chamada o usuário usa o botão "Desconectar" no AppBar
/// (decisão Etapa 3). Isso mantém o `VoiceForegroundService`
/// vivo e a chamada continua minimizada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/voice_participant_model.dart';
import '../../models/voice_room_state_model.dart';
import '../../core/voice_room_overlay_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/voice_room_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/voice/connection_status_badge.dart';
import '../../widgets/voice/mic_control_button.dart';
import '../../widgets/voice/participant_tile.dart';
import '../../widgets/voice/voice_room_minimized_widget.dart';

class VoiceRoomScreen extends ConsumerStatefulWidget {
  const VoiceRoomScreen({
    super.key,
    required this.groupId,
    required this.channelId,
    required this.channelName,
  });

  final String groupId;
  final String channelId;
  final String channelName;

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen> {
  bool _autoConnectDone = false;

  @override
  void initState() {
    super.initState();
    // Marca a tela como ativa (overlay não aparece).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(overlayVisibleProvider.notifier).state = false;
      ref.read(activeVoiceRoomConfigProvider.notifier).state =
          MinimizedWidgetConfig(
        channelId: widget.channelId,
        channelName: widget.channelName,
        onTap: () {}, // Não é usado enquanto a screen está aberta
      );
      if (!_autoConnectDone) {
        _autoConnectDone = true;
        ref.read(voiceRoomControllerProvider.notifier).connect(
              groupId: widget.groupId,
              channelId: widget.channelId,
            );
      }
    });
  }

  @override
  void dispose() {
    // Ao sair da tela, ativa o overlay (se a sala ainda estiver ativa).
    // ignore: invalid_use_of_protected_member, no protected members in this state class
    final state = ref.read(voiceRoomStateStreamProvider(widget.channelId)).asData?.value;
    if (state != null && state.isInRoom) {
      ref.read(overlayVisibleProvider.notifier).state = true;
    }
    super.dispose();
  }

  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sair da sala de voz?'),
          content: const Text(
            'Sua chamada será encerrada e o microfone desligado.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await ref.read(voiceRoomControllerProvider.notifier).disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(voiceRoomStateStreamProvider(widget.channelId));
    final uiState = ref.watch(voiceRoomControllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    // Exibe snackbar de erro fatal só uma vez.
    ref.listen(voiceRoomControllerProvider, (prev, next) {
      if (next.hasError && (prev?.errorMessage != next.errorMessage)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () => ref
                  .read(voiceRoomControllerProvider.notifier)
                  .clearError(),
            ),
          ),
        );
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        // Back do sistema: não desconecta, só sai da tela.
        // O WidgetsBinding e o service mantêm a chamada viva.
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: <Widget>[
              const Icon(Icons.volume_up, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            stateAsync.maybeWhen(
              data: (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ConnectionStatusBadge(
                  state: s.connectionState,
                  errorMessage: s.errorMessage,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            IconButton(
              tooltip: 'Sair da sala',
              icon: const Icon(Icons.call_end, color: Colors.redAccent),
              onPressed: _confirmDisconnect,
            ),
          ],
        ),
        body: _buildBody(context, stateAsync, uiState),
        bottomNavigationBar: _buildFooter(context, stateAsync, uiState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<VoiceRoomState> stateAsync,
    VoiceRoomUiState uiState,
  ) {
    if (uiState.isEntering) {
      return const LoadingIndicator(label: 'Entrando na sala...');
    }
    return stateAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (state) {
        if (state.connectionState == VoiceConnectionState.failed) {
          return _FailedState(
            errorMessage: state.errorMessage ?? 'Não foi possível conectar.',
            onRetry: () => ref
                .read(voiceRoomControllerProvider.notifier)
                .connect(
                  groupId: widget.groupId,
                  channelId: widget.channelId,
                ),
          );
        }
        if (state.participants.isEmpty) {
          return const _EmptyState();
        }
        return _ParticipantsList(
          participants: state.participants,
          currentUserId: currentUserId,
        );
      },
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AsyncValue<VoiceRoomState> stateAsync,
    VoiceRoomUiState uiState,
  ) {
    final state = stateAsync.asData?.value;
    final isConnected = state?.isInRoom ?? false;
    final isMuted = state?.participants
            .where((p) => p.isLocal)
            .firstOrNull
            ?.isMuted ??
        true;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _ParticipantCount(
              count: state?.participantCount ?? 0,
            ),
            MicControlButton(
              state: _micButtonStateFor(uiState, isConnected, isMuted),
              onMuteToggle: (wantMute) {
                ref
                    .read(voiceRoomControllerProvider.notifier)
                    .setMuted(wantMute);
              },
            ),
            const SizedBox(width: 56), // Espelha a largura do botão mic
          ],
        ),
      ),
    );
  }

  MicButtonState _micButtonStateFor(
    VoiceRoomUiState ui,
    bool isConnected,
    bool isMuted,
  ) {
    if (!isConnected) return MicButtonState.noPermission;
    if (ui.isMuteTogglePending) return MicButtonState.transitioning;
    return isMuted ? MicButtonState.muted : MicButtonState.active;
  }
}

class _ParticipantsList extends StatelessWidget {
  const _ParticipantsList({
    required this.participants,
    this.currentUserId,
  });

  final List<VoiceParticipantModel> participants;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ordena: local primeiro, depois falando, depois alfabético.
    final sorted = <VoiceParticipantModel>[...participants];
    sorted.sort((a, b) {
      if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
      if (a.isSpeaking != b.isSpeaking) return a.isSpeaking ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.people,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Em sala — ${sorted.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            itemBuilder: (context, i) {
              final p = sorted[i];
              return ParticipantTile(
                participant: p,
                // Ações de admin ficam para Etapa 3.5 (precisam de
                // permission_resolver + endpoints de mute server-side).
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParticipantCount extends StatelessWidget {
  const _ParticipantCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          count == 1 ? 'pessoa' : 'pessoas',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.headset_mic,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Ninguém na sala ainda',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Convide pessoas do seu grupo para entrar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedState extends StatelessWidget {
  const _FailedState({required this.errorMessage, required this.onRetry});
  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Não foi possível conectar',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

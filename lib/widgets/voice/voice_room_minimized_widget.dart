/// `VoiceRoomMinimizedWidget` — preview compactado da sala de voz.
///
/// Fica sobreposto à UI como `OverlayEntry` ou dentro de um
/// `Stack` quando o usuário saiu da tela de voz mas a chamada
/// continua ativa em segundo plano.
///
/// **Integração com Navigator** fica para a Etapa 4 (foreground
/// service + chamada retorno ao app). Aqui está apenas a UI.
///
/// Layout:
/// - Linha: avatares empilhados dos participantes + contador.
/// - Botão mic (toggle mute local).
/// - Botão desconectar (encerrar chamada).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/voice_room_state_model.dart';
import '../../providers/voice_room_provider.dart';
import 'connection_status_badge.dart';
import 'mic_control_button.dart';

/// Configuração para construir o `VoiceRoomMinimizedWidget`.
class MinimizedWidgetConfig {
  const MinimizedWidgetConfig({
    required this.channelId,
    required this.channelName,
    this.onTap,
    this.position = MinimizedPosition.bottomRight,
  });

  /// Canal ativo.
  final String channelId;

  /// Nome do canal para tooltip.
  final String channelName;

  /// Tap no widget abre a tela completa. Opcional — se null,
  /// o widget ignora o toque (útil quando o manager vai
  /// definir a ação programaticamente).
  final VoidCallback? onTap;

  /// Posição na tela.
  final MinimizedPosition position;
}

enum MinimizedPosition { topLeft, topRight, bottomLeft, bottomRight }

/// Widget de preview flutuante da sala de voz.
///
/// Use `MinimizedVoiceRoomOverlay.of(context)` para encontrar
/// a configuração no árvore (se disponível) e construir o overlay.
///
/// Para teste standalone, o widget pode ser usado diretamente:
/// ```dart
/// VoiceRoomMinimizedWidget(
///   config: MinimizedWidgetConfig(...),
///   roomState: someState,
///   onDisconnect: () {},
///   onMuteToggle: (v) {},
/// )
/// ```
class VoiceRoomMinimizedWidget extends ConsumerWidget {
  const VoiceRoomMinimizedWidget({
    super.key,
    required this.config,
    this.roomState,
    this.onDisconnect,
    this.onMuteToggle,
  });

  /// Configuração de navegação.
  final MinimizedWidgetConfig config;

  /// Estado da sala (opcional; se null, lê do provider).
  final VoiceRoomState? roomState;

  /// Callback para desconectar.
  final VoidCallback? onDisconnect;

  /// Callback para toggle mute.
  final void Function(bool)? onMuteToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = roomState ?? ref.watch(
      voiceRoomStateStreamProvider(config.channelId),
    ).asData?.value;
    final uiState = ref.watch(voiceRoomControllerProvider);
    final theme = Theme.of(context);

    final isMuted =
        state?.participants.where((p) => p.isLocal).firstOrNull?.isMuted ?? true;
    final participantCount = state?.participantCount ?? 0;
    final connectionState = state?.connectionState ?? VoiceConnectionState.disconnected;

    // Se desconectou por fora, não mostra o minimizado.
    if (connectionState == VoiceConnectionState.disconnected) {
      return const SizedBox.shrink();
    }

    final isCompact = participantCount <= 3;
    final avatarSize = isCompact ? 28.0 : 24.0;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: config.onTap != null ? () => config.onTap?.call() : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header: status + canal
              Row(
                children: <Widget>[
                  if (state != null)
                    ConnectionStatusBadge(state: connectionState),
                  const Spacer(),
                  Icon(
                    Icons.volume_up,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      config.channelName,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Linha de avatares
              Row(
                children: <Widget>[
                  _StackedAvatars(
                    participantCount: participantCount,
                    avatarSize: avatarSize,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$participantCount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),

                  // Mic toggle
                  if (onMuteToggle != null)
                    GestureDetector(
                      onTap: () => onMuteToggle?.call(!isMuted),
                      child: _MiniMicIcon(
                        isMuted: isMuted,
                        isPending: uiState.isMuteTogglePending,
                      ),
                    ),

                  const SizedBox(width: 6),

                  // Disconnect
                  if (onDisconnect != null)
                    GestureDetector(
                      onTap: onDisconnect,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.error.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.call_end,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatares empilhados em perspectiva ("3 + N").
class _StackedAvatars extends StatelessWidget {
  const _StackedAvatars({
    required this.participantCount,
    required this.avatarSize,
  });

  final int participantCount;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    // Mostra no máximo 3 avatares empilhados.
    const visible = 3;
    final overlap = avatarSize * 0.55;

    return SizedBox(
      width: avatarSize + (visible - 1) * overlap,
      height: avatarSize,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < visible; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _avatarColor(i),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: avatarSize * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (participantCount > visible)
            Positioned(
              left: visible * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade700,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+${participantCount - visible}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: avatarSize * 0.3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(int i) {
    const colors = [Colors.blue, Colors.purple, Colors.teal];
    return colors[i % colors.length];
  }
}

/// Ícone miniatura de mic para o preview.
class _MiniMicIcon extends StatelessWidget {
  const _MiniMicIcon({
    required this.isMuted,
    required this.isPending,
  });

  final bool isMuted;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final color = isMuted
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: Center(
        child: isPending
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                size: 16,
                color: color,
              ),
      ),
    );
  }
}

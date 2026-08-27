/// `ConnectionStatusBadge` — selo compacto do estado de conexão
/// da sala de voz.
///
/// Mapeia `VoiceConnectionState` para cor, ícone e label:
///
/// | Estado          | Cor      | Ícone           | Label          |
/// |-----------------|----------|-----------------|----------------|
/// | disconnected    | neutro   | mic_off         | Desconectado   |
/// | connecting      | info     | hourglass_empty | Conectando...  |
/// | connected       | sucesso  | check_circle    | Conectado      |
/// | reconnecting    | aviso    | refresh         | Reconectando   |
/// | failed          | erro     | error           | Falhou         |
///
/// Quando `state == failed` e `errorMessage` for passado, o badge
/// mostra tooltip / `onTap` para revelar detalhes.
library;

import 'package:flutter/material.dart';

import '../../models/voice_room_state_model.dart';

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({
    super.key,
    required this.state,
    this.errorMessage,
    this.onTap,
  });

  /// Estado atual da conexão.
  final VoiceConnectionState state;

  /// Mensagem de erro (usada quando `state == failed`).
  final String? errorMessage;

  /// Tap handler opcional. Quando passado, o badge ganha ripple
  /// e cursor, útil para abrir detalhes de erro.
  final VoidCallback? onTap;

  Color _backgroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case VoiceConnectionState.connected:
        return Colors.green.withValues(alpha: 0.18);
      case VoiceConnectionState.connecting:
        return scheme.primary.withValues(alpha: 0.18);
      case VoiceConnectionState.reconnecting:
        return Colors.orange.withValues(alpha: 0.20);
      case VoiceConnectionState.failed:
        return scheme.error.withValues(alpha: 0.18);
      case VoiceConnectionState.disconnected:
        return scheme.onSurface.withValues(alpha: 0.10);
    }
  }

  Color _foregroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case VoiceConnectionState.connected:
        return Colors.green.shade700;
      case VoiceConnectionState.connecting:
        return scheme.primary;
      case VoiceConnectionState.reconnecting:
        return Colors.orange.shade800;
      case VoiceConnectionState.failed:
        return scheme.error;
      case VoiceConnectionState.disconnected:
        return scheme.onSurface.withValues(alpha: 0.7);
    }
  }

  IconData get _icon {
    switch (state) {
      case VoiceConnectionState.connected:
        return Icons.check_circle;
      case VoiceConnectionState.connecting:
        return Icons.hourglass_empty;
      case VoiceConnectionState.reconnecting:
        return Icons.refresh;
      case VoiceConnectionState.failed:
        return Icons.error;
      case VoiceConnectionState.disconnected:
        return Icons.mic_off;
    }
  }

  String get _label {
    switch (state) {
      case VoiceConnectionState.connected:
        return 'Conectado';
      case VoiceConnectionState.connecting:
        return 'Conectando...';
      case VoiceConnectionState.reconnecting:
        return 'Reconectando...';
      case VoiceConnectionState.failed:
        return 'Falhou';
      case VoiceConnectionState.disconnected:
        return 'Desconectado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnecting = state == VoiceConnectionState.connecting ||
        state == VoiceConnectionState.reconnecting;
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isConnecting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_foregroundColor(context)),
              ),
            )
          else
            Icon(_icon, size: 14, color: _foregroundColor(context)),
          const SizedBox(width: 6),
          Text(
            _label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _foregroundColor(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (state == VoiceConnectionState.failed && errorMessage != null) {
            _showErrorSheet(context, errorMessage!);
          } else {
            onTap?.call();
          }
        },
        child: badge,
      ),
    );
  }

  void _showErrorSheet(BuildContext context, String message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.error,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Falha na conexão',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

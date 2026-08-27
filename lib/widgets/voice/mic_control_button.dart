/// `MicControlButton` — botão de mute/desmute do microfone.
///
/// Estados visuais:
/// - **Normal**: ícone mic ativo, cor primária quando não mutado.
/// - **Muted**: ícone mic_off, cor de erro.
/// - **Transição**: ícone com `CircularProgressIndicator` sobreposto,
///   `enabled: false`.
/// - **Pedindo permissão**: label "Permissão", ícone lock,
///   `enabled: false`.
///
/// Eventos:
/// - `onMuteToggle(isMuted)` — notifica o caller sobre a intenção.
///   O caller decide o que fazer (chamar service, pedir permissão, etc.)
///   e então atualiza `isMuted` / `isTransitioning`.
library;

import 'package:flutter/material.dart';

/// Estado funcional do botão.
enum MicButtonState {
  /// Mic ativo, pronto para mutar.
  active,

  /// Mic mutado pelo usuário.
  muted,

  /// Transição em andamento (mute/unmute pendente).
  transitioning,

  /// Sem permissão de mic (permanentemente negada).
  noPermission,
}

/// `MicControlButton` — botão principal de controle do microfone.
///
/// Use `MicButtonState` para alimentar o widget e `onMuteToggle`
/// para reagir.
///
/// Exemplo de uso:
/// ```dart
/// MicControlButton(
///   state: state.isMuted ? MicButtonState.muted : MicButtonState.active,
///   onMuteToggle: (wantMute) => controller.setMuted(wantMute),
/// )
/// ```
class MicControlButton extends StatelessWidget {
  const MicControlButton({
    super.key,
    required this.state,
    required this.onMuteToggle,
    this.size = 56,
    this.showLabel = true,
  });

  /// Estado funcional atual.
  final MicButtonState state;

  /// Chamado quando o usuário toca o botão.
  /// `wantMute == true` → usuário quer mutar.
  /// `wantMute == false` → usuário quer desmutar.
  final void Function(bool wantMute) onMuteToggle;

  /// Tamanho do botão circular (default 56).
  final double size;

  /// Se `true`, mostra label de texto abaixo do ícone (default `true`).
  final bool showLabel;

  bool get _isMuted => state == MicButtonState.muted;
  bool get _isEnabled =>
      state != MicButtonState.transitioning && state != MicButtonState.noPermission;

  Color _backgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (state) {
      case MicButtonState.active:
        return theme.colorScheme.surfaceContainerHighest;
      case MicButtonState.muted:
        return theme.colorScheme.errorContainer;
      case MicButtonState.transitioning:
        return theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5);
      case MicButtonState.noPermission:
        return theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5);
    }
  }

  Color _foregroundColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (state) {
      case MicButtonState.active:
        return theme.colorScheme.primary;
      case MicButtonState.muted:
        return theme.colorScheme.error;
      case MicButtonState.transitioning:
        return theme.colorScheme.onSurface.withValues(alpha: 0.4);
      case MicButtonState.noPermission:
        return theme.colorScheme.onSurface.withValues(alpha: 0.4);
    }
  }

  IconData get _icon {
    switch (state) {
      case MicButtonState.active:
        return Icons.mic;
      case MicButtonState.muted:
        return Icons.mic_off;
      case MicButtonState.transitioning:
        return _isMuted ? Icons.mic_off : Icons.mic;
      case MicButtonState.noPermission:
        return Icons.lock;
    }
  }

  String get _label {
    switch (state) {
      case MicButtonState.active:
        return 'Mutar';
      case MicButtonState.muted:
        return 'Desmutar';
      case MicButtonState.transitioning:
        return '...';
      case MicButtonState.noPermission:
        return 'Sem acesso';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: _isEnabled
              ? () => onMuteToggle(!_isMuted)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor(context),
              boxShadow: _isEnabled && _isMuted
                  ? <BoxShadow>[
                      BoxShadow(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  _icon,
                  color: _foregroundColor(context),
                  size: size * 0.45,
                ),
                if (state == MicButtonState.transitioning)
                  SizedBox(
                    width: size * 0.8,
                    height: size * 0.8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _foregroundColor(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showLabel) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _foregroundColor(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// `ParticipantTile` — linha de participante em uma sala de voz.
///
/// Mostra:
/// - Avatar com anel de fala animado quando `isSpeaking == true`.
/// - Nome + indicadores (mutado, admin, local).
/// - Ícone de mic (mutado / falando).
///
/// Interação:
/// - `onAdminMute` / `onAdminKick` opcionais. Quando fornecidos,
///   long-press abre menu de admin (Etapa 3 implementa as ações
///   de fato; aqui só dispara a UI).
library;

import 'package:flutter/material.dart';

import '../../models/voice_participant_model.dart';
import '../common/app_avatar.dart';

class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    this.onAdminMute,
    this.onAdminKick,
    this.onTap,
  });

  final VoiceParticipantModel participant;

  /// O usuário atual pode silenciar este participante.
  /// A policy (cargo, etc.) é responsabilidade de quem chama.
  final VoidCallback? onAdminMute;

  /// O usuário atual pode expulsar este participante.
  final VoidCallback? onAdminKick;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = participant;
    final showAdminMenu = onAdminMute != null || onAdminKick != null;

    return InkWell(
      onTap: onTap,
      onLongPress: showAdminMenu ? () => _showAdminMenu(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            _SpeakingAvatar(participant: p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          p.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: p.isLocal
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: p.isSpeaking
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.isLocal) ...<Widget>[
                        const SizedBox(width: 6),
                        _Tag(label: 'você', theme: theme),
                      ],
                    ],
                  ),
                  if (showAdminMenu)
                    Text(
                      'Pressione e segure para ações de moderador',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MicIcon(participant: p, theme: theme),
          ],
        ),
      ),
    );
  }

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  participant.displayName,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              if (onAdminMute != null)
                ListTile(
                  leading: const Icon(Icons.mic_off),
                  title: Text(
                    participant.isMuted ? 'Desmutar' : 'Silenciar',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAdminMute!();
                  },
                ),
              if (onAdminKick != null)
                ListTile(
                  leading: const Icon(
                    Icons.person_remove,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Expulsar da sala',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAdminKick!();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar com anel animado quando o participante está falando.
class _SpeakingAvatar extends StatelessWidget {
  const _SpeakingAvatar({required this.participant});
  final VoiceParticipantModel participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: participant.isSpeaking ? baseColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: participant.isSpeaking
            ? <BoxShadow>[
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: _PulsingRing(
        isSpeaking: participant.isSpeaking,
        color: baseColor,
        child: AppAvatar(
          name: participant.displayName,
          photoUrl: participant.photoUrl,
          uid: participant.userId,
          size: 40,
        ),
      ),
    );
  }
}

/// Pulso suave em volta do anel enquanto fala.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({
    required this.isSpeaking,
    required this.color,
    required this.child,
  });
  final bool isSpeaking;
  final Color color;
  final Widget child;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSpeaking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.08 + 0.12 * t),
          ),
          padding: EdgeInsets.all(2 + 2 * t),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _MicIcon extends StatelessWidget {
  const _MicIcon({required this.participant, required this.theme});
  final VoiceParticipantModel participant;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = participant.isMuted
        ? theme.colorScheme.error
        : (participant.isSpeaking
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.6));

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(
        participant.isMuted ? Icons.mic_off : Icons.mic,
        color: color,
        size: 18,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

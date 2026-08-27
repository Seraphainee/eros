/// `VoiceRoomOverlayManager` — gerencia a exibição do `VoiceRoomMinimizedWidget`
/// sobre a UI enquanto o usuário está em uma sala de voz mas não está
/// na `VoiceRoomScreen`.
///
/// Ciclo de vida:
/// 1. `VoiceRoomScreen` é empurrada → `showMinimized` fica `false`.
/// 2. `VoiceRoomScreen` dá pop → `showMinimized` vira `true`.
/// 3. Se `isInRoom == true` → overlay sobe com o widget minimizado.
/// 4. Usuário toca o widget → abre `VoiceRoomScreen` novamente.
/// 5. `disconnect()` ou sala vazia → overlay desce.
///
/// Integração: coloque este widget no topo da árvore (dentro de
/// `MaterialApp.child`) e conecte o `navigatorKey` ao mesmo
/// `Overlay navigatorKey`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/voice_room_state_model.dart';
import '../providers/voice_room_provider.dart';
import '../screens/voice/voice_room_screen.dart';
import '../widgets/voice/voice_room_minimized_widget.dart';

/// Provider global que sinaliza se o overlay deve aparecer.
///
/// `true` = o usuário NÃO está na VoiceRoomScreen mas PODE estar
/// em uma sala ativa (back foi dado, screen foi fechada).
final overlayVisibleProvider = StateProvider<bool>((ref) => false);

/// Provider com a config da sala ativa para o minimizado.
///
/// Null quando não há sala ativa.
final activeVoiceRoomConfigProvider = StateProvider<MinimizedWidgetConfig?>(
  (ref) => null,
);

/// Widget que deve ser inserido como filho de `MaterialApp`
/// (ou dentro do builder de `Overlay`) para o overlay funcionar.
///
/// Uso típico em `app.dart`:
/// ```dart
/// MaterialApp(
///   navigatorKey: _navKey,
///   builder: (context, child) => VoiceRoomOverlayShell(
///     navKey: _navKey,
///     child: child!,
///   ),
///   ...
/// )
/// ```
class VoiceRoomOverlayShell extends ConsumerStatefulWidget {
  const VoiceRoomOverlayShell({
    super.key,
    required this.navKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navKey;
  final Widget child;

  @override
  ConsumerState<VoiceRoomOverlayShell> createState() =>
      _VoiceRoomOverlayShellState();
}

class _VoiceRoomOverlayShellState extends ConsumerState<VoiceRoomOverlayShell>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  String? _activeChannelId;
  String? _activeChannelName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se o app vai para background enquanto em sala de voz,
    // o VoiceForegroundService (Android) mantém a chamada viva.
    // O overlay já está visível neste ponto — não precisa de ação extra.
  }

  void _maybePushOverlay() {
    if (!mounted) return;
    final showMinimized = ref.read(overlayVisibleProvider);
    final config = ref.read(activeVoiceRoomConfigProvider);

    if (showMinimized && config != null) {
      _activeChannelId = config.channelId;
      _activeChannelName = config.channelName;
      _insertOverlay(config);
    } else {
      _removeOverlay();
    }
  }

  void _insertOverlay(MinimizedWidgetConfig config) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 24,
        right: 16,
        child: VoiceRoomMinimizedWidget(
          config: MinimizedWidgetConfig(
            channelId: config.channelId,
            channelName: config.channelName,
            position: config.position,
            onTap: () => _handleReopen(),
          ),
          onDisconnect: _handleDisconnect,
          onMuteToggle: _handleMuteToggle,
        ),
      ),
    );
    widget.navKey.currentState?.overlay?.insert(_overlayEntry!);
  }

  void _handleReopen() {
    final config = ref.read(activeVoiceRoomConfigProvider);
    if (config == null) return;
    ref.read(overlayVisibleProvider.notifier).state = false;
    _removeOverlay();
    final nav = widget.navKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute<void>(
      builder: (_) => VoiceRoomScreen(
        groupId: '',
        channelId: config.channelId,
        channelName: config.channelName,
      ),
    ));
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _handleDisconnect() async {
    await ref.read(voiceRoomControllerProvider.notifier).disconnect();
    ref.read(overlayVisibleProvider.notifier).state = false;
    ref.read(activeVoiceRoomConfigProvider.notifier).state = null;
    _activeChannelId = null;
    _activeChannelName = null;
    _removeOverlay();
  }

  void _handleMuteToggle(bool wantMute) {
    ref.read(voiceRoomControllerProvider.notifier).setMuted(wantMute);
  }

  @override
  Widget build(BuildContext context) {
    // Escuta mudanças de overlay visibility.
    ref.listen<bool>(overlayVisibleProvider, (_, __) => _maybePushOverlay());
    ref.listen<MinimizedWidgetConfig?>(
      activeVoiceRoomConfigProvider,
      (_, __) => _maybePushOverlay(),
    );

    // Escuta o estado da sala para manter overlay visível enquanto
    // a chamada estiver ativa (mesmo sem showMinimized).
    ref.listen<VoiceRoomState?>(
      voiceRoomStateProvider,
      (prev, next) {
        if (next == null || !next.isInRoom) {
          // Sala encerrou — remove tudo.
          ref.read(overlayVisibleProvider.notifier).state = false;
          ref.read(activeVoiceRoomConfigProvider.notifier).state = null;
          _activeChannelId = null;
          _activeChannelName = null;
          _removeOverlay();
        }
      },
    );

    return widget.child;
  }
}

/// Provider simples que retorna o estado atual da sala de voz.
///
/// Diferente do `voiceRoomStateStreamProvider` (por canal), este
/// expõe o estado global singletons do service.
final voiceRoomStateProvider = Provider<VoiceRoomState?>((ref) {
  final service = ref.watch(voiceRoomServiceProvider);
  return service.currentState;
});

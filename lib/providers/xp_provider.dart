/// Provider Riverpod para o heartbeat de XP.
///
/// Segue o mesmo padrão de `auth_provider.dart`/`profile_provider.dart`:
/// service exposto via `Provider`, e aqui um segundo `Provider` que,
/// ao ser observado (`ref.watch`), dispara um `Timer.periodic` que
/// credita XP a cada `XpConstants.heartbeatIntervalSeconds` enquanto
/// o usuário estiver autenticado com o app em primeiro plano — ver
/// `XpService` para a regra de negócio completa.
///
/// Usado em `app.dart` (`_AuthGate`): `ref.watch(xpHeartbeatProvider)`
/// enquanto autenticado. Como é um `Provider` (não `.autoDispose`)
/// observado a partir de um widget que só existe na árvore quando
/// autenticado, o timer é automaticamente cancelado (via `ref.onDispose`)
/// quando esse widget sai da árvore — isto é, no logout.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/xp_constants.dart';
import '../core/utils/logger.dart';
import '../services/profile/xp_service.dart';
import 'auth_provider.dart';

/// Service de XP.
final Provider<XpService> xpServiceProvider = Provider<XpService>((ref) {
  return XpService();
});

/// Mantém o heartbeat de XP vivo enquanto observado. Não expõe estado
/// de UI — é usado apenas pelo efeito colateral do `Timer.periodic`.
final Provider<void> xpHeartbeatProvider = Provider<void>((ref) {
  final service = ref.watch(xpServiceProvider);

  Timer? timer;

  void tick() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    // Best-effort: falha de heartbeat não deve derrubar o timer nem
    // a sessão do usuário (mesma filosofia de `XpService`).
    service
        .creditHeartbeat(userId: user.uid, vipTier: user.vipTier)
        .catchError((Object e, StackTrace st) {
      Logger.w('xpHeartbeatProvider: heartbeat falhou: $e');
    });
  }

  timer = Timer.periodic(
    const Duration(seconds: XpConstants.heartbeatIntervalSeconds),
    (_) => tick(),
  );

  ref.onDispose(() => timer?.cancel());
  return null;
});
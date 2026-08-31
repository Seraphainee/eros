/// `XpService` — credita XP de usuário por tempo com o app aberto.
///
/// Regra de negócio (confirmada pelo dono do produto):
/// - XP acumula por TEMPO COM O APP ABERTO, em qualquer tela — não
///   precisa estar numa sala de voz.
/// - Taxa base: `XpConstants.basePointsPerMinute`.
/// - Multiplicador de VIP: 1x (normal), 4x (VIP), 8x (VIP+).
/// - Se o usuário estiver DENTRO de um canal de voz com
///   `xpMultiplier` próprio (> 1), esse multiplicador se aplica
///   também — pensado para ajudar quem não é VIP a compensar.
///
/// Composição dos multiplicadores: quando o usuário está numa sala
/// com bônus, usa-se o MAIOR entre (multiplicador de VIP) e
/// (multiplicador da sala) — não a soma nem o produto. Isso evita
/// que um VIP+ numa sala "XP 8x" ganhe 64x (8 * 8), o que fugiria
/// da intenção de "a sala ajuda quem não é VIP a se equiparar", não
/// de multiplicar ainda mais quem já tem o benefício mais alto.
///
/// Chamado por um Provider (ver `xp_provider.dart`) que dispara um
/// `Timer.periodic` enquanto o app está em primeiro plano.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/xp_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/channel_model.dart';

class XpService {
  XpService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Credita o XP correspondente a um intervalo de heartbeat
  /// (`XpConstants.heartbeatIntervalSeconds`) para [userId].
  ///
  /// [vipTier] vem do perfil já carregado em memória (evita 1 leitura
  /// extra por heartbeat). [activeChannel] é o canal de voz em que o
  /// usuário está conectado agora, se houver — usado para aplicar o
  /// multiplicador de sala quando maior que o de VIP.
  Future<void> creditHeartbeat({
    required String userId,
    required VipTier vipTier,
    ChannelModel? activeChannel,
  }) async {
    final vipMultiplier = XpConstants.vipMultiplier[vipTier] ?? 1;
    final roomMultiplier = (activeChannel != null && activeChannel.isVoice)
        ? activeChannel.xpMultiplier.clamp(1, XpConstants.maxRoomMultiplier)
        : 1;
    // Maior dos dois — não soma nem multiplica (ver doc da classe).
    final effectiveMultiplier =
        vipMultiplier > roomMultiplier ? vipMultiplier : roomMultiplier;

    final minutesPerHeartbeat = XpConstants.heartbeatIntervalSeconds / 60;
    final pointsEarned = (XpConstants.basePointsPerMinute *
            minutesPerHeartbeat *
            effectiveMultiplier)
        .round();

    if (pointsEarned <= 0) return;

    try {
      await _usersRef.doc(userId).update(<String, dynamic>{
        'xpPoints': FieldValue.increment(pointsEarned),
      });
    } on FirebaseException catch (e, st) {
      // XP é best-effort: uma falha pontual de heartbeat não deve
      // interromper a sessão do usuário. Loga e segue.
      Logger.w('XpService.creditHeartbeat falhou para $userId: ${e.message}');
      if (e.code == 'not-found') {
        throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
      }
    }
  }
}
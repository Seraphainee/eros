/// Providers de estado para navegação de canais.
///
/// Mantém o estado da UI de "em qual canal estou":
/// - grupo selecionado
/// - canal selecionado
///
/// O `GroupDetailScreen` e a `TextChannelScreen` consomem estes
/// providers para saber qual contexto estão exibindo.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grupo atualmente aberto.
final selectedGroupIdProvider = StateProvider<String?>((ref) => null);

/// Canal atualmente aberto.
final selectedChannelIdProvider = StateProvider<String?>((ref) => null);

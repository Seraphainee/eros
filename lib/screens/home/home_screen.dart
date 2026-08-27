/// `HomeScreen` — ponto de entrada do usuário autenticado.
///
/// Por enquanto é um wrapper que mostra a `GroupListScreen`.
/// Em etapas seguintes vai abrigar o rail de navegação
/// (presença, notificações, ranking).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../group/group_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const GroupListScreen();
  }
}

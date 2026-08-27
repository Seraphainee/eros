/// `GroupListScreen` — lista de grupos do usuário.
///
/// Mostra os grupos em que o usuário é membro, com FAB para
/// criar novo grupo (placeholder para a Etapa 3.5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'group_detail_screen.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/app_avatar.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.user?.uid;
    if (userId == null) {
      return const LoadingIndicator(label: 'Autenticando…');
    }
    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus grupos'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (groups) {
          if (groups.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(userGroupsStreamProvider(userId)),
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _GroupTile(group: groups[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Criar grupo'),
        onPressed: () {
          // Etapa 3.5: tela de criação de grupo.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Criação de grupo em breve.')),
          );
        },
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});
  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: AppAvatar(
        name: group.name,
        photoUrl: group.iconUrl,
        uid: group.id,
        size: 44,
      ),
      title: Text(group.name),
      subtitle: Text('${group.memberCount} membro(s)'),
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.groups_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Você ainda não participa de nenhum grupo.\nToque em "Criar grupo" para começar.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

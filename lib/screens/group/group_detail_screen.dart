/// `GroupDetailScreen` — sidebar de canais do grupo.
///
/// Mostra o nome/ícone do grupo no topo e a lista de canais
/// (texto e voz) abaixo. Toque em um canal de texto abre
/// `TextChannelScreen`. Canais de voz ficam com ícone de
/// speaker (placeholder para Etapa 4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/app_avatar.dart';
import '../channel/text_channel_screen.dart';
import '../voice/voice_room_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupStreamProvider(groupId));
    final channelsAsync = ref.watch(channelsStreamProvider(groupId));
    final selectedChannelId = ref.watch(selectedChannelIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.when(
          loading: () => const Text('…'),
          error: (e, _) => const Text('Grupo'),
          data: (g) => g == null
              ? const Text('Grupo')
              : Row(
                  children: <Widget>[
                    AppAvatar(
                      name: g.name,
                      photoUrl: g.iconUrl,
                      uid: g.id,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(g.name),
                  ],
                ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Etapa 3.5: GroupSettingsScreen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configurações em breve.')),
              );
            },
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (channels) {
          if (channels.isEmpty) {
            return const Center(child: Text('Nenhum canal ainda.'));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              for (final ch in channels)
                _ChannelTile(
                  channel: ch,
                  selected: ch.id == selectedChannelId,
                  onTap: () {
                    ref.read(selectedChannelIdProvider.notifier).state = ch.id;
                    if (ch.isText) {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => TextChannelScreen(
                            groupId: groupId,
                            channelId: ch.id,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => VoiceRoomScreen(
                            groupId: groupId,
                            channelId: ch.id,
                            channelName: ch.name,
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final ChannelModel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        channel.isText ? Icons.tag : Icons.volume_up,
        color: selected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        channel.name,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

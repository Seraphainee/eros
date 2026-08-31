/// `GroupDetailScreen` — tela do "servidor" (card do grupo + canais).
///
/// Réplica do fluxo de referência: no topo, o card do grupo com
/// ícone emoldurado, nome, badges (ID único, nível, online, membros)
/// e os botões Curtir/Favoritar (visíveis a QUALQUER membro). Abaixo,
/// a lista de canais (texto e voz) com contagem de presença ao vivo e
/// avatares de quem está na chamada — inclusive em canais protegidos
/// por senha, que mostram um cadeado e continuam listando quem está
/// dentro para qualquer pessoa (dono, membro ou visitante), mas
/// pedem senha antes de deixar ENTRAR (o dono sempre entra livre).
///
/// O menu (⋮) sempre aparece, mas o CONTEÚDO muda por papel:
/// - Qualquer membro: Enquete (votar; criar é exclusivo de dono/admin,
///   tratado dentro da própria tela de enquete) e Convidar membro.
/// - Exclusivo do dono: Fazer anúncio, Criar canal, Ordem dos canais,
///   Configurações do grupo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel_model.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/voice_room_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/loading_indicator.dart';
import '../channel/text_channel_screen.dart';
import '../voice/voice_room_screen.dart';
import 'channel_create_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupStreamProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('servidor'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Membros',
            onPressed: () {
              // TODO: MembersListScreen (etapa futura).
            },
          ),
          groupAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (group) {
              if (group == null) return const SizedBox.shrink();
              final uid = ref.watch(currentUserIdProvider);
              final isOwner = uid != null && group.ownerId == uid;
              // O botão (⋮) aparece para TODOS. O conteúdo do menu
              // muda: Enquete e Convidar membro ficam visíveis para
              // qualquer membro; Fazer anúncio, Criar canal, Ordem
              // dos canais e Configurações são exclusivos do dono.
              return _GroupOptionsMenuButton(
                groupId: groupId,
                isOwner: isOwner,
              );
            },
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Grupo não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              _GroupCard(group: group),
              const SizedBox(height: 20),
              _ChannelListSection(groupId: groupId),
            ],
          );
        },
      ),
    );
  }
}

/// Card superior: ícone, nome, badges e botões curtir/favoritar.
/// Visível e utilizável por QUALQUER membro do grupo (dono ou não).
class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onlineCountAsync = ref.watch(groupOnlineCountProvider(group.id));
    final isLikedAsync = ref.watch(groupIsLikedProvider(group.id));
    final isFavoritedAsync = ref.watch(groupIsFavoritedProvider(group.id));
    final likeController = ref.read(groupLikeControllerProvider.notifier);

    final onlineCount = onlineCountAsync.valueOrNull ?? 0;
    final isLiked = isLikedAsync.valueOrNull ?? false;
    final isFavorited = isFavoritedAsync.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primary.withValues(alpha: 0.16),
            const Color(0xFF1A1A22),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _GroupIcon(group: group),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.slogan != null && group.slogan!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        group.slogan!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Badge(
                          icon: Icons.tag,
                          label: group.displayId,
                          color: theme.colorScheme.primary,
                        ),
                        _Badge(
                          icon: Icons.shield_outlined,
                          label: 'Nível ${group.level}',
                        ),
                        _Badge(
                          icon: Icons.circle,
                          iconSize: 8,
                          iconColor: const Color(0xFF2ECC71),
                          label: '$onlineCount Online',
                        ),
                        _Badge(
                          icon: Icons.groups_outlined,
                          label: '${group.memberCount} Membros',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionChip(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: 'Curtir · ${group.likeCount}',
                  activeColor: const Color(0xFFE53E5E),
                  active: isLiked,
                  onTap: () => likeController.toggleLike(group.id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionChip(
                  icon: isFavorited ? Icons.star : Icons.star_border,
                  label: 'Favoritado',
                  activeColor: const Color(0xFFF5A623),
                  active: isFavorited,
                  onTap: () => likeController.toggleFavorite(group.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ícone do grupo com moldura em gradiente (imita a moldura dourada
/// da referência, adaptada à paleta azul/roxa do app).
class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF7C4DFF), Color(0xFF4A9DFF)],
        ),
      ),
      child: ClipOval(
        child: group.iconUrl != null && group.iconUrl!.isNotEmpty
            ? Image.network(group.iconUrl!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF1A1A22),
                alignment: Alignment.center,
                child: Text(
                  group.displayId.replaceFirst('#', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    this.color,
    this.iconColor,
    this.iconSize = 14,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: iconSize, color: iconColor ?? c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c == Colors.white70 ? Colors.white70 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color activeColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: active ? activeColor : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seção "CANAIS N" + lista.
class _ChannelListSection extends ConsumerWidget {
  const _ChannelListSection({required this.groupId});

  final String groupId;

  /// Trata o toque num canal: se for de texto, abre direto. Se for
  /// de voz e tiver senha, pede a senha antes (exceto para o dono,
  /// que sempre entra livre). Se a senha bater ou não houver senha,
  /// navega para a sala.
  Future<void> _handleChannelTap({
    required BuildContext context,
    required WidgetRef ref,
    required ChannelModel channel,
  }) async {
    ref.read(selectedChannelIdProvider.notifier).state = channel.id;

    if (channel.isText) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TextChannelScreen(
            groupId: groupId,
            channelId: channel.id,
          ),
        ),
      );
      return;
    }

    // Canal de voz. Verifica se precisa de senha.
    if (channel.isPasswordProtected) {
      final group = await ref.read(groupStreamProvider(groupId).future);
      final uid = ref.read(currentUserIdProvider);
      final isOwner = group != null && uid != null && group.ownerId == uid;

      if (!isOwner) {
        if (!context.mounted) return;
        final entered = await _promptPassword(context, ref, channel);
        if (entered != true) return; // usuário cancelou ou senha errada
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VoiceRoomScreen(
          groupId: groupId,
          channelId: channel.id,
          channelName: channel.name,
        ),
      ),
    );
  }

  /// Mostra o diálogo de senha. Retorna `true` se a senha digitada
  /// bateu (usuário pode entrar), `false`/`null` caso contrário.
  Future<bool?> _promptPassword(
    BuildContext context,
    WidgetRef ref,
    ChannelModel channel,
  ) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16161D),
              title: Row(
                children: <Widget>[
                  const Icon(Icons.lock, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Canal protegido: ${channel.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Digite a senha do canal',
                  hintStyle: const TextStyle(color: Colors.white38),
                  errorText: errorText,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                onSubmitted: (_) {
                  final ok = ref
                      .read(channelServiceProvider)
                      .verifyPassword(channel, controller.text);
                  if (ok) {
                    Navigator.of(dialogContext).pop(true);
                  } else {
                    setState(() => errorText = 'Senha incorreta.');
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final ok = ref
                        .read(channelServiceProvider)
                        .verifyPassword(channel, controller.text);
                    if (ok) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setState(() => errorText = 'Senha incorreta.');
                    }
                  },
                  child: const Text('Entrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsStreamProvider(groupId));
    final selectedChannelId = ref.watch(selectedChannelIdProvider);

    return channelsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Erro ao carregar canais: $e'),
      ),
      data: (channels) {
        if (channels.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum canal ainda.')),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'CANAIS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${channels.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16161D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < channels.length; i++) ...<Widget>[
                    _ChannelTile(
                      groupId: groupId,
                      channel: channels[i],
                      selected: channels[i].id == selectedChannelId,
                      onTap: () => _handleChannelTap(
                        context: context,
                        ref: ref,
                        channel: channels[i],
                      ),
                    ),
                    if (i != channels.length - 1)
                      const Divider(height: 1, color: Color(0xFF222229)),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({
    required this.groupId,
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final String groupId;
  final ChannelModel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presenceAsync = channel.isVoice
        ? ref.watch(channelPresenceProvider(channel.id))
        : null;
    final presentUserIds = presenceAsync?.valueOrNull ?? const <String>[];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  channel.isText ? Icons.tag : Icons.volume_up,
                  size: 20,
                  color: selected ? theme.colorScheme.primary : Colors.white54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? theme.colorScheme.primary : Colors.white,
                    ),
                  ),
                ),
                if (channel.isPasswordProtected) ...<Widget>[
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock, size: 15, color: Colors.white38),
                  ),
                ],
                if (channel.isVoice) ...<Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.person, size: 12, color: Colors.white54),
                        const SizedBox(width: 3),
                        Text(
                          '${presentUserIds.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (channel.isVoice && presentUserIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final uid in presentUserIds)
                      AppAvatar(name: uid, uid: uid, size: 24),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menu (⋮) do topo.
///
/// - Todos os membros veem: Enquete (dono/admin cria; membro comum
///   só vota — a distinção acontece dentro da tela de enquete, não
///   aqui) e Convidar membro (busca por nome/ID + botão convidar).
/// - Exclusivo do dono: Fazer anúncio, Criar canal, Ordem dos
///   canais, Configurações do grupo.
class _GroupOptionsMenuButton extends ConsumerWidget {
  const _GroupOptionsMenuButton({
    required this.groupId,
    required this.isOwner,
  });

  final String groupId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'poll':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enquete em breve.')),
            );
            break;
          case 'invite':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Convidar membro em breve.')),
            );
            break;
          case 'announcement':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fazer anúncio em breve.')),
            );
            break;
          case 'create_channel':
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChannelCreateScreen(groupId: groupId),
              ),
            );
            break;
          case 'reorder_channels':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ordem dos canais em breve.')),
            );
            break;
          case 'settings':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configurações em breve.')),
            );
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        // --- Visível a qualquer membro ---
        const PopupMenuItem<String>(
          value: 'poll',
          child: _MenuRow(icon: Icons.bar_chart, label: 'Enquete'),
        ),
        const PopupMenuItem<String>(
          value: 'invite',
          child: _MenuRow(icon: Icons.person_add_alt, label: 'Convidar membro'),
        ),
        // --- Exclusivo do dono ---
        if (isOwner) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'announcement',
            child: _MenuRow(icon: Icons.campaign_outlined, label: 'Fazer anúncio'),
          ),
          const PopupMenuItem<String>(
            value: 'create_channel',
            child: _MenuRow(icon: Icons.add_box_outlined, label: 'Criar canal'),
          ),
          const PopupMenuItem<String>(
            value: 'reorder_channels',
            child: _MenuRow(icon: Icons.reorder, label: 'Ordem dos canais'),
          ),
          const PopupMenuItem<String>(
            value: 'settings',
            child: _MenuRow(icon: Icons.tune, label: 'Configurações do grupo'),
          ),
        ],
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
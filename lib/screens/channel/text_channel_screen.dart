/// `TextChannelScreen` — chat de texto de um canal.
///
/// Layout:
/// - AppBar com nome do canal + info do grupo.
/// - Lista de mensagens (scroll para baixo = novas; para cima =
///   histórico paginado).
/// - `MessageInputBar` fixa no rodapé.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/message_input_bar.dart';

class TextChannelScreen extends ConsumerStatefulWidget {
  const TextChannelScreen({
    super.key,
    required this.groupId,
    this.channelId,
  });

  final String groupId;
  final String? channelId;

  @override
  ConsumerState<TextChannelScreen> createState() => _TextChannelScreenState();
}

class _TextChannelScreenState extends ConsumerState<TextChannelScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Garante que o `selectedGroupIdProvider` esteja setado para o
    // ChatController (caso o usuário tenha chegado aqui via deep link
    // sem passar pelo GroupDetailScreen).
    Future.microtask(() {
      if (!mounted) return;
      ref.read(selectedGroupIdProvider.notifier).state = widget.groupId;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final channelId = widget.channelId;
    if (channelId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selecione um canal')),
        body: const Center(
          child: Text('Abra o grupo e escolha um canal de texto.'),
        ),
      );
    }
    final messagesAsync = ref.watch(channelMessagesStreamProvider(channelId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.maybeWhen(
          data: (g) => g == null
              ? const Text('Canal')
              : Text('${g.name} · #${_placeholderName(channelId)}'),
          orElse: () => const Text('Canal'),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Seja o primeiro a enviar uma mensagem.'),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    // reverse:true => index 0 é a mais recente
                    final msg = messages[messages.length - 1 - i];
                    return MessageBubble(
                      message: msg,
                      authorName: msg.authorId == currentUserId
                          ? 'Você'
                          : _placeholderName(msg.authorId),
                      isMine: msg.authorId == currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          MessageInputBar(channelId: channelId),
        ],
      ),
    );
  }

  /// Placeholder de nome até o `ProfileService` (Etapa 3.5) existir.
  String _placeholderName(String idOrChannel) {
    if (idOrChannel.length <= 8) return idOrChannel;
    return idOrChannel.substring(0, 8);
  }
}

/// `MessageInputBar` — barra inferior de digitação.
///
/// Estados:
/// - Normal: campo vazio, mostra botão de enviar desabilitado.
/// - Reply/Edit: mostra chip de contexto acima do campo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attachment_model.dart';
import '../../providers/chat_provider.dart';

class MessageInputBar extends ConsumerStatefulWidget {
  const MessageInputBar({
    super.key,
    required this.channelId,
  });

  final String channelId;

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    final controller = ref.read(chatControllerProvider(widget.channelId).notifier);
    final state = ref.read(chatControllerProvider(widget.channelId));
    if (state.editingMessageId != null) {
      controller.confirmEditing(
        messageId: state.editingMessageId!,
        newContent: text,
      );
    } else {
      controller.send(content: text);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.channelId));
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (state.editingMessageId != null)
              _ContextBar(
                text: 'Editando mensagem',
                onCancel: () {
                  ref
                      .read(chatControllerProvider(widget.channelId).notifier)
                      .cancelEditing();
                },
              ),
            if (state.replyToMessage != null)
              _ContextBar(
                text: 'Respondendo a: ${state.replyToMessage!.content}',
                onCancel: () {
                  ref
                      .read(chatControllerProvider(widget.channelId).notifier)
                      .clearReply();
                },
              ),
            if (state.pendingAttachments.isNotEmpty)
              _PendingAttachmentsBar(attachments: state.pendingAttachments),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Etapa 3.5: abre sheet de seleção de anexo.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anexos: seleção de arquivo em breve.'),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Mensagem',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: state.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.send,
                          color: _hasText
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                  onPressed: _hasText && !state.isSending ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentsBar extends StatelessWidget {
  const _PendingAttachmentsBar({required this.attachments});
  final List<AttachmentModel> attachments;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${attachments.length} anexo(s) pendente(s)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

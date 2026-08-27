/// `MessageBubble` — balão de mensagem.
///
/// Layout:
/// - Avatar à esquerda.
/// - Header: nome do autor + timestamp.
/// - Conteúdo (texto + anexos).
/// - Footer: indicadores de "editado" e ações (long-press).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../models/attachment_model.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../common/app_avatar.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.authorName,
    this.authorPhotoUrl,
    this.isMine = false,
  });

  final MessageModel message;
  final String authorName;
  final String? authorPhotoUrl;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timestamp = du.DateUtils.formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(
            name: authorName,
            photoUrl: authorPhotoUrl,
            uid: message.authorId,
            size: 36,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showActions(context, ref),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timestamp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (message.isEdited) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          '(editado)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (message.isReply && message.replyToId != null)
                    _ReplyChip(message: message),
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (message.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: message.attachments
                            .map((a) => _AttachmentChip(attachment: a))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chatControllerProvider(message.channelId).notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Responder'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.setReplyTo(message);
                },
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.startEditing(message);
                  },
                ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Apagar', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.delete(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.message});
  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Text(
        '↳ Reply',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment});
  final AttachmentModel attachment;

  IconData get _icon {
    switch (attachment.type) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.video:
        return Icons.video_library;
      case AttachmentType.audio:
        return Icons.audiotrack;
      case AttachmentType.file:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_icon, size: 16),
          const SizedBox(width: 4),
          Text(attachment.fileName,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

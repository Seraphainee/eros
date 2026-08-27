/// Modelo de dados para Message (mensagem de texto em um canal).
///
/// Documento em `messages/{messageId}`. Organização: coleção raiz
/// (não sub-coleção de canal) para permitir queries globais de
/// moderação. A query do canal é filtrada por `channelId` com
/// índice composto `channelId + createdAt`.
///
/// Implementação manual imutável — idêntica estratégia dos outros models.
import 'attachment_model.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.channelId,
    required this.groupId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.attachments = const <AttachmentModel>[],
    this.replyToId,
    this.editedAt,
    this.deletedAt,
    this.mentions = const <String>[],
  });

  /// ID da mensagem.
  final String id;

  /// ID do canal onde a mensagem foi postada.
  final String channelId;

  /// ID do grupo (desnormalizado para queries de moderação).
  final String groupId;

  /// UID do autor.
  final String authorId;

  /// Conteúdo de texto puro (já sanitizado pelo `MessageService`).
  final String content;

  /// Anexos embarcados.
  final List<AttachmentModel> attachments;

  /// ID da mensagem original quando é uma reply.
  final String? replyToId;

  /// Quando a mensagem foi criada.
  final DateTime createdAt;

  /// Quando foi editada pela última vez (null se nunca).
  final DateTime? editedAt;

  /// Soft-delete: quando foi apagada (null se ainda visível).
  final DateTime? deletedAt;

  /// UIDs mencionados (@user). Para a Etapa 7 (notificações).
  final List<String> mentions;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isReply => replyToId != null;

  MessageModel copyWith({
    String? id,
    String? channelId,
    String? groupId,
    String? authorId,
    String? content,
    List<AttachmentModel>? attachments,
    String? replyToId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    List<String>? mentions,
    bool clearReply = false,
    bool clearEdit = false,
    bool clearDelete = false,
  }) {
    return MessageModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      replyToId: clearReply ? null : (replyToId ?? this.replyToId),
      createdAt: createdAt ?? this.createdAt,
      editedAt: clearEdit ? null : (editedAt ?? this.editedAt),
      deletedAt: clearDelete ? null : (deletedAt ?? this.deletedAt),
      mentions: mentions ?? this.mentions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'channelId': channelId,
        'groupId': groupId,
        'authorId': authorId,
        'content': content,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'replyToId': replyToId,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'mentions': mentions,
      };

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        channelId: json['channelId'] as String,
        groupId: json['groupId'] as String,
        authorId: json['authorId'] as String,
        content: (json['content'] as String?) ?? '',
        attachments: ((json['attachments'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => AttachmentModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        replyToId: json['replyToId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] == null
            ? null
            : DateTime.parse(json['editedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        mentions: ((json['mentions'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e as String)
            .toList(growable: false),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel &&
        other.id == id &&
        other.channelId == channelId &&
        other.groupId == groupId &&
        other.authorId == authorId &&
        other.content == content &&
        other.replyToId == replyToId &&
        other.createdAt == createdAt &&
        other.editedAt == editedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        channelId,
        groupId,
        authorId,
        content,
        replyToId,
        createdAt,
        editedAt,
        deletedAt,
      );

  @override
  String toString() =>
      'MessageModel(id: $id, channelId: $channelId, authorId: $authorId)';
}

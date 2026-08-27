/// Providers Riverpod para os services de chat.
///
/// Estado de chat por canal: mensagens, loading, paginação,
/// anexo em progresso, e ações (enviar/editar/apagar).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../models/attachment_model.dart';
import '../models/message_model.dart';
import '../services/chat/attachment_service.dart';
import '../services/chat/message_pagination_service.dart';
import '../services/chat/message_service.dart';
import 'channel_provider.dart';

/// ─── Providers base (services) ───────────────────────────────────────────

final messageServiceProvider = Provider<MessageService>((ref) => MessageService());

final paginationServiceProvider =
    Provider<MessagePaginationService>((ref) => MessagePaginationService());

final attachmentServiceProvider = Provider<AttachmentService>((ref) => AttachmentService());

/// ─── Estado de chat por canal ─────────────────────────────────────────────
///
/// `Family` com `channelId` como parâmetro: cada canal tem seu
/// estado isolado. Quando o usuário sai do canal, o provider é
/// descartado automaticamente pelo Riverpod.

/// Mensagens do canal (stream em tempo real).
final channelMessagesStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, channelId) {
  return ref.watch(messageServiceProvider).watchChannelMessages(channelId);
});

/// Estado da UI do chat (loading, erro, enviando, editando, reply).
class ChatUiState {
  const ChatUiState({
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.editingMessageId,
    this.replyToMessage,
    this.pendingAttachments = const [],
    this.hasMorePages = true,
  });

  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final String? editingMessageId;      // != null = modo edição ativo
  final MessageModel? replyToMessage;  // != null = modo reply ativo
  final List<AttachmentModel> pendingAttachments;
  final bool hasMorePages;

  ChatUiState copyWith({
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    String? editingMessageId,
    MessageModel? replyToMessage,
    List<AttachmentModel>? pendingAttachments,
    bool? hasMorePages,
    bool clearError = false,
    bool clearEdit = false,
    bool clearReply = false,
  }) {
    return ChatUiState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      editingMessageId: clearEdit ? null : (editingMessageId ?? this.editingMessageId),
      replyToMessage: clearReply ? null : (replyToMessage ?? this.replyToMessage),
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      hasMorePages: hasMorePages ?? this.hasMorePages,
    );
  }
}

class ChatController extends StateNotifier<ChatUiState> {
  ChatController(this._ref, this._groupId, this._channelId)
      : _service = _ref.read(messageServiceProvider),
        _pagination = _ref.read(paginationServiceProvider),
        _attachment = _ref.read(attachmentServiceProvider),
        super(const ChatUiState()) {
    _loadInitial();
  }

  final Ref _ref;
  final String _groupId;
  final String _channelId;
  final MessageService _service;
  final MessagePaginationService _pagination;
  final AttachmentService _attachment;

  DateTime? _oldestCursor;

  void _loadInitial() {
    state = state.copyWith(isLoading: true);
    // O stream do provider já está escutando; esperamos o primeiro emit.
    // Marcação de loading será limpa quando o stream ProviderFamily
    // tiver o primeiro valor.
  }

  void _onFirstMessage() {
    state = state.copyWith(isLoading: false);
  }

  /// Envia mensagem.
  Future<void> send({
    required String content,
    List<AttachmentModel>? attachments,
  }) async {
    if ((content.trim().isEmpty) && (attachments == null || attachments.isEmpty)) {
      return;
    }
    state = state.copyWith(isSending: true, clearError: true);
    try {
      await _service.sendMessage(
        groupId: _groupId,
        channelId: _channelId,
        content: content,
        attachments: attachments ?? <AttachmentModel>[],
        replyToId: state.replyToMessage?.id,
        mentions: _extractMentions(content),
      );
      state = state.copyWith(isSending: false, clearReply: true);
    } on AppException catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.message);
      Logger.w('ChatController.send falhou: ${e.message}');
    }
  }

  /// Inicia modo de edição de uma mensagem.
  void startEditing(MessageModel message) {
    state = state.copyWith(editingMessageId: message.id);
  }

  /// Confirma a edição.
  Future<void> confirmEditing({
    required String messageId,
    required String newContent,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      await _service.editMessage(messageId: messageId, newContent: newContent);
      state = state.copyWith(isSending: false, clearEdit: true);
    } on AppException catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.message);
    }
  }

  /// Cancela modo de edição.
  void cancelEditing() {
    state = state.copyWith(clearEdit: true);
  }

  /// Define mensagem de reply.
  void setReplyTo(MessageModel message) {
    state = state.copyWith(replyToMessage: message);
  }

  /// Limpa reply ativo.
  void clearReply() {
    state = state.copyWith(clearReply: true);
  }

  /// Apaga mensagem.
  Future<void> delete(String messageId) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      await _service.deleteMessage(messageId: messageId);
      state = state.copyWith(isSending: false);
    } on AppException catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.message);
    }
  }

  /// Carrega próxima página de mensagens mais antigas.
  Future<void> loadOlderPage() async {
    if (!state.hasMorePages || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _pagination.loadOlderPage(
        channelId: _channelId,
        before: _oldestCursor,
      );
      _oldestCursor = result.nextCursor;
      state = state.copyWith(
        isLoading: false,
        hasMorePages: result.nextCursor != null,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  /// Quando o stream ProviderFamily emite o primeiro valor,
  /// a UI pode chamar isto para parar o skeleton.
  void markFirstMessageReceived() => _onFirstMessage();

  List<String> _extractMentions(String content) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(content).map((m) => m.group(1)!).toList();
  }
}

/// Provider family por channelId.
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatUiState, String>(
  (ref, channelId) {
    // Sem acesso ao groupId diretamente — a Screen é responsável por
    // manter `selectedGroupIdProvider` atualizado.
    final groupId = ref.watch(selectedGroupIdProvider) ?? '';
    return ChatController(ref, groupId, channelId);
  },
);

/// Provider de histórico paginado para o scroll para cima.
final olderMessagesProvider =
    FutureProvider.family<List<MessageModel>, ({String channelId, DateTime? before})>(
  (ref, params) async {
    final pagination = ref.read(paginationServiceProvider);
    final result = await pagination.loadOlderPage(
      channelId: params.channelId,
      before: params.before,
    );
    return result.messages;
  },
);

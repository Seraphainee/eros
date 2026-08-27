/// `AttachmentService` — upload de anexos para Firebase Storage.
///
/// Caminho: `groups/{groupId}/channels/{channelId}/{messageId}/{fileName}`.
/// Cada upload devolve um `AttachmentModel` com URL pública pronta
/// para ser embarcada em `MessageModel.attachments`.
///
/// Limites:
/// - Tamanho: `AppConstants.maxAttachmentSizeBytes` (10 MB por padrão).
/// - Tipo: decidido pelo chamador (`AttachmentType`).
///
/// Esta etapa entrega o esqueleto. A UI completa (seleção de
/// arquivo via `image_picker`, preview antes do envio, barra de
/// progresso) fica para a Etapa 3.5.
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../models/attachment_model.dart';

class AttachmentService {
  AttachmentService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Upload a partir de bytes (útil para `image_picker` em mobile/web).
  Future<AttachmentModel> uploadBytes({
    required String groupId,
    required String channelId,
    required String messageId,
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
    String? mimeType,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    if (bytes.lengthInBytes > AppConstants.maxAttachmentSizeBytes) {
      throw const AuthException(message: 'attachment-too-large');
    }
    final ref = _refFor(
      groupId: groupId,
      channelId: channelId,
      messageId: messageId,
      fileName: fileName,
    );
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: <String, String>{'type': type.name},
    );
    try {
      final task = await ref.putData(bytes, metadata);
      final url = await task.ref.getDownloadURL();
      Logger.i('AttachmentService: upload bytes $fileName -> $url');
      return AttachmentModel(
        id: messageId,
        type: type,
        url: url,
        fileName: fileName,
        sizeBytes: bytes.lengthInBytes,
        mimeType: mimeType,
        width: width,
        height: height,
        durationMs: durationMs,
      );
    } on FirebaseException catch (e, st) {
      throw FirestoreException(
        message: e.message ?? e.code,
        stackTrace: st,
      );
    }
  }

  /// Upload a partir de um caminho de arquivo local (mobile/desktop).
  Future<AttachmentModel> uploadFile({
    required String groupId,
    required String channelId,
    required String messageId,
    required File file,
    required String fileName,
    required AttachmentType type,
    String? mimeType,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final size = await file.length();
    if (size > AppConstants.maxAttachmentSizeBytes) {
      throw const AuthException(message: 'attachment-too-large');
    }
    final ref = _refFor(
      groupId: groupId,
      channelId: channelId,
      messageId: messageId,
      fileName: fileName,
    );
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: <String, String>{'type': type.name},
    );
    try {
      final task = await ref.putFile(file, metadata);
      final url = await task.ref.getDownloadURL();
      Logger.i('AttachmentService: upload file $fileName -> $url');
      return AttachmentModel(
        id: messageId,
        type: type,
        url: url,
        fileName: fileName,
        sizeBytes: size,
        mimeType: mimeType,
        width: width,
        height: height,
        durationMs: durationMs,
      );
    } on FirebaseException catch (e, st) {
      throw FirestoreException(
        message: e.message ?? e.code,
        stackTrace: st,
      );
    }
  }

  /// Apaga um anexo do Storage. Não remove o registro em
  /// `messages/{id}.attachments[]` — o chamador deve editar a
  /// mensagem se quiser.
  Future<void> deleteAttachment(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e, st) {
      throw FirestoreException(
        message: e.message ?? e.code,
        stackTrace: st,
      );
    }
  }

  Reference _refFor({
    required String groupId,
    required String channelId,
    required String messageId,
    required String fileName,
  }) {
    return _storage.ref(
      'groups/$groupId/channels/$channelId/$messageId/$fileName',
    );
  }
}

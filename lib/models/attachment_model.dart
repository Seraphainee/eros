/// Modelo de dados para Attachment (anexo de mensagem).
///
/// Documento embutido em `messages/{id}.attachments[]` (não é coleção
/// separada — anexos são imutáveis e sempre lidos junto com a mensagem).
///
/// Implementação manual imutável — idêntica estratégia dos outros models.
enum AttachmentType { image, video, audio, file }

class AttachmentModel {
  const AttachmentModel({
    required this.id,
    required this.type,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.width,
    this.height,
    this.durationMs,
  });

  /// ID do anexo (gerado no client).
  final String id;

  /// Tipo: image, video, audio, file.
  final AttachmentType type;

  /// URL pública no Firebase Storage.
  final String url;

  /// Nome original do arquivo (para download).
  final String fileName;

  /// Tamanho em bytes.
  final int sizeBytes;

  /// MIME type (`image/png`, `video/mp4`...). Pode ser null se desconhecido.
  final String? mimeType;

  /// Largura (imagens/vídeos).
  final int? width;

  /// Altura (imagens/vídeos).
  final int? height;

  /// Duração em ms (áudio/vídeo).
  final int? durationMs;

  AttachmentModel copyWith({
    String? id,
    AttachmentType? type,
    String? url,
    String? fileName,
    int? sizeBytes,
    String? mimeType,
    int? width,
    int? height,
    int? durationMs,
  }) {
    return AttachmentModel(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'url': url,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'width': width,
        'height': height,
        'durationMs': durationMs,
      };

  factory AttachmentModel.fromJson(Map<String, dynamic> json) => AttachmentModel(
        id: json['id'] as String,
        type: AttachmentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AttachmentType.file,
        ),
        url: json['url'] as String,
        fileName: json['fileName'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        mimeType: json['mimeType'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationMs: (json['durationMs'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentModel &&
        other.id == id &&
        other.type == type &&
        other.url == url &&
        other.fileName == fileName &&
        other.sizeBytes == sizeBytes &&
        other.mimeType == mimeType &&
        other.width == width &&
        other.height == height &&
        other.durationMs == durationMs;
  }

  @override
  int get hashCode => Object.hash(
      id, type, url, fileName, sizeBytes, mimeType, width, height, durationMs);

  @override
  String toString() =>
      'AttachmentModel(id: $id, type: $type, fileName: $fileName)';
}

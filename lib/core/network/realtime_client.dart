/// Cliente genérico de realtime para Firestore.
///
/// Abstrai operações de escuta (snapshots) e escrita com retry
/// automático e tratamento de erros consistente.
///
/// Usado por: MessageService, PresenceService, VoiceSignalingService, etc.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../errors/app_exception.dart';

class RealtimeClient {
  RealtimeClient({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Stream de documentos com tratamento de erro.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuery(
    Query<Map<String, dynamic>> query, {
    Duration? throttle,
  }) {
    Stream<QuerySnapshot<Map<String, dynamic>>> stream = query.snapshots(
      includeMetadataChanges: true,
    );

    if (throttle != null) {
      stream = stream.throttle(throttle);
    }

    return stream.handleError((error, stackTrace) {
      throw FirestoreException(
        message: error.toString(),
        stackTrace: stackTrace,
      );
    });
  }

  /// Stream de documento único.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    return ref.snapshots(includeMetadataChanges: true).handleError((error, stackTrace) {
      throw FirestoreException(
        message: error.toString(),
        stackTrace: stackTrace,
      );
    });
  }

  /// Escrita com retry automático (até 3 tentativas).
  Future<void> writeWithRetry(
    Future<void> Function() operation, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
  }) async {
    var attempt = 0;
    while (true) {
      try {
        await operation();
        return;
      } on FirebaseException catch (e, st) {
        attempt++;
        if (attempt >= maxRetries || !_isRetryable(e.code)) {
          throw FirestoreException(
            message: e.message ?? e.code,
            stackTrace: st,
          );
        }
        await Future.delayed(baseDelay * attempt);
      }
    }
  }

  bool _isRetryable(String code) {
    return code == 'unavailable' ||
           code == 'deadline-exceeded' ||
           code == 'aborted' ||
           code == 'internal';
  }

  /// Transação com retry automático.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) transaction, {
    int maxRetries = 3,
  }) {
    return _firestore.runTransaction(transaction, maxAttempts: maxRetries);
  }

  /// Batch write.
  WriteBatch batch() => _firestore.batch();
}
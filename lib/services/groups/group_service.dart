/// Curte ou descurte o grupo. Idempotente: chamar de novo com o
  /// mesmo estado não gera erro. Atualiza `likeCount` via transação
  /// para evitar corrida em cliques rápidos.
  Future<void> toggleLike({
    required String groupId,
    required String userId,
  }) async {
    final likeRef =
        _groupsRef.doc(groupId).collection('likes').doc(userId);
    final groupRef = _groupsRef.doc(groupId);

    try {
      await _firestore.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        final groupSnap = await tx.get(groupRef);
        if (!groupSnap.exists) {
          throw const FirestoreException(message: 'group-not-found');
        }
        final currentCount =
            (groupSnap.data()?['likeCount'] as int?) ?? 0;

        if (likeSnap.exists) {
          tx.delete(likeRef);
          tx.update(groupRef, <String, dynamic>{
            'likeCount': (currentCount - 1).clamp(0, 1 << 31),
          });
        } else {
          tx.set(likeRef, <String, dynamic>{
            'userId': userId,
            'likedAt': DateTime.now().toIso8601String(),
          });
          tx.update(groupRef, <String, dynamic>{
            'likeCount': currentCount + 1,
          });
        }
      });
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream de se [userId] curtiu o grupo [groupId].
  Stream<bool> watchIsLikedByUser({
    required String groupId,
    required String userId,
  }) {
    return _groupsRef
        .doc(groupId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Favorita ou desfavorita o grupo para [userId]. Guardado no
  /// perfil do usuário (`users/{userId}/favoriteGroups/{groupId}`)
  /// — diferente de `likes`, que é público e pertence ao grupo.
  Future<void> toggleFavorite({
    required String groupId,
    required String userId,
  }) async {
    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteGroups')
        .doc(groupId);
    try {
      final snap = await favRef.get();
      if (snap.exists) {
        await favRef.delete();
      } else {
        await favRef.set(<String, dynamic>{
          'groupId': groupId,
          'favoritedAt': DateTime.now().toIso8601String(),
        });
      }
    } on FirebaseException catch (e, st) {
      throw FirestoreException(message: e.message ?? e.code, stackTrace: st);
    }
  }

  /// Stream de se [userId] favoritou o grupo [groupId].
  Stream<bool> watchIsFavoritedByUser({
    required String groupId,
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteGroups')
        .doc(groupId)
        .snapshots()
        .map((snap) => snap.exists);
  }
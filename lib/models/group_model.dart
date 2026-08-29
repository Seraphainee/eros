/// Stream: grupo curtido pelo usuário atual?
final groupIsLikedProvider =
    StreamProvider.family<bool, String>((ref, groupId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(groupServiceProvider).watchIsLikedByUser(
        groupId: groupId,
        userId: uid,
      );
});

/// Stream: grupo favoritado pelo usuário atual?
final groupIsFavoritedProvider =
    StreamProvider.family<bool, String>((ref, groupId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(groupServiceProvider).watchIsFavoritedByUser(
        groupId: groupId,
        userId: uid,
      );
});

/// Controller para os botões Curtir/Favoritar (evita duplo-clique
/// disparando duas transações ao mesmo tempo).
final groupLikeControllerProvider =
    AsyncNotifierProvider<GroupLikeController, void>(
        GroupLikeController.new);

class GroupLikeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> toggleLike(String groupId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref
        .read(groupServiceProvider)
        .toggleLike(groupId: groupId, userId: uid));
  }

  Future<void> toggleFavorite(String groupId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref
        .read(groupServiceProvider)
        .toggleFavorite(groupId: groupId, userId: uid));
  }
}
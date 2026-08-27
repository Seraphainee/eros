/// Providers Riverpod para os services de grupos, canais, memberships
/// e permissões.
///
/// Estes providers seguem o mesmo padrão do `authServiceProvider`:
/// o construtor padrão lança `UnimplementedError` para forçar a
/// sobrescrita no `ProviderScope` da raiz. Isso garante que todas
/// as instâncias compartilhem a mesma `FirebaseFirestore` (injetada
/// via `RealtimeClient` na Etapa 1) e a mesma `PermissionResolver`
/// (com o cache coerente entre todos os consumers).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel_model.dart';
import '../models/group_model.dart';
import '../services/channels/channel_permission_service.dart';
import '../services/channels/channel_service.dart';
import '../services/groups/group_service.dart';
import '../services/groups/invite_service.dart';
import '../services/groups/membership_service.dart';
import '../services/permissions/permission_resolver.dart';

/// Resolver de permissões compartilhado por todos os services.
///
/// Inicializado em `app.dart` (Etapa 3) e injetado via override.
final Provider<PermissionResolver> permissionResolverProvider =
    Provider<PermissionResolver>((ref) {
  throw UnimplementedError(
    'permissionResolverProvider deve ser sobrescrito no ProviderScope da raiz.',
  );
});

/// Service de grupos.
final Provider<GroupService> groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(
    permissionResolver: ref.watch(permissionResolverProvider),
  );
});

/// Service de memberships (membros de grupo).
final Provider<MembershipService> membershipServiceProvider =
    Provider<MembershipService>((ref) {
  return MembershipService(
    permissionResolver: ref.watch(permissionResolverProvider),
  );
});

/// Service de convites.
final Provider<InviteService> inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService(
    membershipService: ref.watch(membershipServiceProvider),
  );
});

/// Service de canais.
final Provider<ChannelService> channelServiceProvider = Provider<ChannelService>((ref) {
  return ChannelService(
    permissionResolver: ref.watch(permissionResolverProvider),
  );
});

/// Fachada de permissões de canal (usada pelo chat e pela voz).
final Provider<ChannelPermissionService> channelPermissionServiceProvider =
    Provider<ChannelPermissionService>((ref) {
  return ChannelPermissionService(
    permissionResolver: ref.watch(permissionResolverProvider),
  );
});

// --- Streams reativos (UI) ---

/// Stream dos grupos do usuário autenticado.
final StreamProviderFamily<List<GroupModel>, String>
    userGroupsStreamProvider =
    StreamProvider.family<List<GroupModel>, String>((ref, userId) {
  return ref.watch(groupServiceProvider).watchUserGroups(userId);
});

/// Stream de um grupo específico.
final StreamProviderFamily<GroupModel?, String> groupStreamProvider =
    StreamProvider.family<GroupModel?, String>((ref, groupId) {
  return ref.watch(groupServiceProvider).watchGroup(groupId);
});

/// Stream de canais de um grupo, ordenados.
final StreamProviderFamily<List<ChannelModel>, String> channelsStreamProvider =
    StreamProvider.family<List<ChannelModel>, String>((ref, groupId) {
  return ref.watch(channelServiceProvider).watchChannels(groupId);
});

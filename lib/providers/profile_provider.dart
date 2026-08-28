/// Providers Riverpod para o perfil do usuário.
///
/// Segue o mesmo padrão de `auth_provider.dart`/`group_provider.dart`:
/// service exposto via `Provider`, estado de UI via `StateNotifier`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../models/user_model.dart';
import '../services/profile/profile_service.dart';

/// Service de perfil.
final Provider<ProfileService> profileServiceProvider =
    Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Stream do perfil de um usuário (usada tanto na tela de perfil
/// próprio quanto, futuramente, no perfil de terceiros).
final StreamProviderFamily<UserModel?, String> profileStreamProvider =
    StreamProvider.family<UserModel?, String>((ref, userId) {
  return ref.watch(profileServiceProvider).watchProfile(userId);
});

// --- Edição de perfil (estado de UI) ---

class ProfileEditState {
  const ProfileEditState({
    required this.isLoading,
    required this.errorMessage,
    required this.success,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool success;

  static const ProfileEditState initial = ProfileEditState(
    isLoading: false,
    errorMessage: null,
    success: false,
  );

  ProfileEditState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
    bool clearError = false,
  }) {
    return ProfileEditState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      success: success ?? this.success,
    );
  }
}

class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(this._service) : super(ProfileEditState.initial);

  final ProfileService _service;

  Future<void> save({
    required String userId,
    String? displayName,
    String? signature,
    String? bio,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, success: false);
    try {
      await _service.updateProfile(
        userId: userId,
        displayName: displayName,
        signature: signature,
        bio: bio,
      );
      state = state.copyWith(isLoading: false, success: true);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e.message),
      );
      Logger.w('ProfileEditController.save falhou: ${e.message}');
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível salvar o perfil. Tente novamente.',
      );
      Logger.e('ProfileEditController.save erro inesperado', stackTrace: st);
    }
  }

  String _friendlyMessage(String message) {
    if (message.startsWith('invalid-display-name:') ||
        message.startsWith('invalid-signature:') ||
        message.startsWith('invalid-bio:')) {
      return message.split(':').last.trim();
    }
    return 'Erro ao salvar perfil. Tente novamente.';
  }

  void reset() => state = ProfileEditState.initial;
}

final StateNotifierProvider<ProfileEditController, ProfileEditState>
    profileEditControllerProvider =
    StateNotifierProvider<ProfileEditController, ProfileEditState>((ref) {
  return ProfileEditController(ref.watch(profileServiceProvider));
});
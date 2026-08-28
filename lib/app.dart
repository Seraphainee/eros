/// `ErosApp` — widget raiz do aplicativo.
///
/// Configura:
/// - `ProviderScope` com os serviços injetados pelo bootstrap;
/// - tema dark inspirado em apps de comunicação (Discord-like);
/// - roteamento baseado no estado de autenticação;
/// - `VoiceRoomOverlayShell` para o widget flutuante de sala de voz.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/app_bootstrap.dart';
import 'core/voice_room_overlay_manager.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/voice_room_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth/auth_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/session_manager.dart';
import 'services/permissions/permission_resolver.dart';

class ErosApp extends ConsumerWidget {
  const ErosApp({super.key, required this.bootstrapState});

  final AppBootstrapState bootstrapState;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = SessionManager(bootstrapState.sharedPreferences);
    final auth = AuthService(
      authRepository: AuthRepository(),
      sessionManager: session,
    );
    final resolver = PermissionResolver();

    return ProviderScope(
      overrides: <Override>[
        authServiceProvider.overrideWithValue(auth),
        sessionManagerProvider.overrideWithValue(session),
        permissionResolverProvider.overrideWithValue(resolver),
        voiceRoomServiceProvider.overrideWithValue(bootstrapState.voiceService),
      ],
      child: MaterialApp(
        title: 'EROS',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: _buildTheme(),
        builder: (context, child) {
          return VoiceRoomOverlayShell(
            navKey: navigatorKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _AuthGate(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF7C4DFF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F14),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF0F0F14),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Decide o que renderizar com base no estado de autenticação.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  // Controla qual tela de auth mostrar quando não autenticado.
  bool _showRegister = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    if (state.isLoading) {
      return const _BootSplash();
    }
    if (state.isAuthenticated) {
      return const HomeScreen();
    }
    if (_showRegister) {
      return RegisterScreen(
        onSwitchToLogin: () => setState(() => _showRegister = false),
      );
    }
    return LoginScreen(
      onSwitchToRegister: () => setState(() => _showRegister = true),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
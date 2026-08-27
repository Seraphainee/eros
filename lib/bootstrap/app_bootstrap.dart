/// Bootstrap do aplicativo EROS.
///
/// Responsável por:
/// 1. Inicializar o Flutter e os bindings necessários.
/// 2. Inicializar o Firebase (Auth + Firestore).
/// 3. Configurar a orientação e preferências globais.
/// 4. Configurar logs de acordo com o ambiente.
///
/// Esta rotina é executada uma única vez no `main()` antes de
/// `runApp()`. Falhas aqui são fatais — o app não inicia.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/realtime_client.dart';
import '../core/utils/logger.dart';
import '../services/voice/voice_room_service.dart';
import '../services/voice/voice_room_stub_service.dart';
import 'env_config.dart';

/// Estado produzido pelo bootstrap — injetado no app via Riverpod.
class AppBootstrapState {
  AppBootstrapState({
    required this.sharedPreferences,
    required this.connectivityService,
    required this.realtimeClient,
    required this.voiceService,
  });

  final SharedPreferences sharedPreferences;
  final ConnectivityService connectivityService;
  final RealtimeClient realtimeClient;

  /// Instância do VoiceRoomService (real ou stub).
  final VoiceRoomService voiceService;
}

class AppBootstrap {
  AppBootstrap._();

  /// Executa a sequência de inicialização.
  ///
  /// Deve ser chamado no `main()` antes do `runApp()`.
  static Future<AppBootstrapState> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Travar orientação ao retrato (UX principal do app é vertical).
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await _initFirebase();
    await _configureLogging();
    final prefs = await _initPreferences();
    final connectivity = await _initConnectivity();
    final realtime = RealtimeClient();
    final voiceService = _buildVoiceService();

    Logger.i(
      'Bootstrap concluído (env=${EnvConfig.isDev ? "dev" : "prod"}, '
      'voiceStub=${EnvConfig.voiceStubMode}).',
    );

    return AppBootstrapState(
      sharedPreferences: prefs,
      connectivityService: connectivity,
      realtimeClient: realtime,
      voiceService: voiceService,
    );
  }

  static VoiceRoomService _buildVoiceService() {
    if (EnvConfig.voiceStubMode) {
      // Stub local que simula sala de voz sem backend.
      // Útil para testes de APK sem LiveKit/token server.
      return VoiceRoomServiceStub.create(
        liveKitUrl: EnvConfig.liveKitUrl.isEmpty
            ? 'wss://stub.example.com'
            : EnvConfig.liveKitUrl,
        tokenServerUrl: EnvConfig.liveKitTokenServerUrl,
      );
    }
    // Serviço real (requer LiveKit + token server configurados).
    return VoiceRoomService(
      tokenServerUrl: EnvConfig.liveKitTokenServerUrl.isEmpty
          ? null
          : EnvConfig.liveKitTokenServerUrl,
      liveKitUrl: EnvConfig.liveKitUrl.isEmpty ? null : EnvConfig.liveKitUrl,
    );
  }

  static Future<void> _initFirebase() async {
    final options = FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKey.isEmpty
          ? 'dev-placeholder-api-key'
          : EnvConfig.firebaseApiKey,
      appId: EnvConfig.firebaseAppId.isEmpty
          ? '1:0000000000:android:0000000000000000'
          : EnvConfig.firebaseAppId,
      messagingSenderId: EnvConfig.firebaseMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
    );

    try {
      await Firebase.initializeApp(options: options);
      Logger.i('Firebase inicializado (project=${EnvConfig.firebaseProjectId}).');
    } on Exception catch (e, st) {
      Logger.wtf('Falha ao inicializar Firebase', stackTrace: st);
      Error.throwWithStackTrace(
        Exception('Firebase init failed: $e'),
        st,
      );
    }
  }

  static Future<void> _configureLogging() async {
    if (!EnvConfig.isDev && kReleaseMode) {
      // Em produção suprime logs verbosos; só erros são mostrados.
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  }

  static Future<SharedPreferences> _initPreferences() {
    return SharedPreferences.getInstance();
  }

  static Future<ConnectivityService> _initConnectivity() async {
    final service = ConnectivityService();
    // Aguarda o estado inicial estabilizar para evitar race conditions
    // com o primeiro evento de presence.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return service;
  }
}

/// Auxiliar para garantir timeouts consistentes em chamadas de auth
/// durante o bootstrap.
Duration authBootstrapTimeout() => AppConstants.authTimeout;

/// Service de conectividade de rede.
///
/// Monitora mudanças no estado da conexão de internet e expõe um
/// stream de eventos para que outros services possam reagir
/// (ex: reconexão automática de voz).
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../errors/app_exception.dart';

enum ConnectionState { online, offline, unknown }

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  late final StreamController<ConnectionState> _controller;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectionState _currentState = ConnectionState.unknown;

  Stream<ConnectionState> get onStateChange => _controller.stream;
  ConnectionState get currentState => _currentState;
  bool get isOnline => _currentState == ConnectionState.online;

  Future<void> _init() async {
    _controller = StreamController<ConnectionState>.broadcast();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleChange);
    // Verifica o estado atual imediatamente.
    final initial = await _connectivity.checkConnectivity();
    _handleChange(initial);
  }

  void _handleChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    final newState = hasNetwork ? ConnectionState.online : ConnectionState.offline;
    if (newState != _currentState) {
      _currentState = newState;
      _controller.add(newState);
      if (kDebugMode) {
        debugPrint('ConnectivityService: state -> $newState');
      }
    }
  }

  /// Espera até a conexão estar online. Útil para bloquear UI antes
  /// de uma ação que exige rede.
  Future<void> waitUntilOnline({Duration timeout = const Duration(seconds: 30)}) async {
    if (isOnline) return;
    final completer = Completer<void>();
    late StreamSubscription<ConnectionState> sub;
    sub = onStateChange.listen((state) {
      if (state == ConnectionState.online) {
        sub.cancel();
        completer.complete();
      }
    });
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      sub.cancel();
      throw const NetworkException(message: 'Timeout esperando conexão online.');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
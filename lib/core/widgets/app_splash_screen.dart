/// `AppSplashScreen` — tela de carregamento com a identidade visual
/// do EROS: fundo de partículas (`ParticleBackground`) + o wordmark
/// `ErosLogo` com animação de entrada (fade + escala) e um pulso de
/// brilho contínuo enquanto o app termina de inicializar.
///
/// Uso: renderizada em `app.dart`, dentro de `_AuthGate`, sempre que
/// `authControllerProvider` ainda está com `isLoading == true` — ou
/// seja, ela substitui o antigo `_BootSplash` (que era só um spinner
/// sobre fundo escuro).
import 'package:flutter/material.dart';

import 'eros_logo.dart';
import 'particle_background.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ParticleBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_introController, _pulseController]),
            builder: (context, _) {
              return Opacity(
                opacity: _fadeIn.value,
                child: Transform.scale(
                  scale: _scaleIn.value,
                  child: Opacity(
                    // O pulso só afeta o brilho depois que a entrada terminou,
                    // multiplicando sobre o fadeIn já concluído (valor 1.0).
                    opacity: _introController.isCompleted ? _pulse.value : 1.0,
                    child: const ErosLogo(fontSize: 56),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
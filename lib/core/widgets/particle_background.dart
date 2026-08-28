/// Fundo animado de partículas flutuantes — usado nas telas de
/// autenticação (login/registro) para dar a identidade visual do EROS:
/// preto profundo com partículas azul-escuro/roxo subindo lentamente,
/// como poeira estelar.
///
/// Implementado com `CustomPainter` puro (sem pacotes externos) para não
/// adicionar dependências novas ao projeto.
import 'dart:math';

import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({
    super.key,
    this.particleCount = 46,
    this.child,
  });

  /// Quantidade de partículas simultâneas na tela.
  final int particleCount;

  /// Conteúdo renderizado por cima do fundo (ex: formulário).
  final Widget? child;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final Random _random = Random();

  // Paleta azul-escuro quase roxo, do mais "roxo" ao mais "azul".
  static const List<Color> _palette = <Color>[
    Color(0xFF2A1B6E), // roxo profundo
    Color(0xFF3B2A8C), // roxo-azulado
    Color(0xFF25316B), // azul-arroxeado
    Color(0xFF1B2A63), // azul-escuro
    Color(0xFF4A3AA8), // roxo mais claro (destaque)
  ];

  @override
  void initState() {
    super.initState();
    _particles = List<_Particle>.generate(
      widget.particleCount,
      (_) => _Particle.random(_random),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Fundo preto com leve gradiente azul-roxo profundo nos cantos.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: <Color>[
                Color(0xFF161029),
                Color(0xFF000000),
              ],
              stops: <double>[0.0, 0.75],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                progress: _controller.value,
                palette: _palette,
              ),
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y0,
    required this.radius,
    required this.speed,
    required this.driftAmplitude,
    required this.driftPhase,
    required this.colorIndex,
    required this.opacity,
  });

  factory _Particle.random(Random random) {
    return _Particle(
      x: random.nextDouble(),
      y0: random.nextDouble(),
      radius: 1.0 + random.nextDouble() * 2.6,
      speed: 0.05 + random.nextDouble() * 0.12,
      driftAmplitude: 6 + random.nextDouble() * 18,
      driftPhase: random.nextDouble() * 2 * pi,
      colorIndex: random.nextInt(5),
      opacity: 0.25 + random.nextDouble() * 0.55,
    );
  }

  /// Posição horizontal base (0..1, fração da largura).
  final double x;

  /// Posição vertical inicial (0..1, fração da altura).
  final double y0;

  final double radius;
  final double speed;
  final double driftAmplitude;
  final double driftPhase;
  final int colorIndex;
  final double opacity;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.palette,
  });

  final List<_Particle> particles;
  final double progress;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Sobe continuamente e recomeça embaixo ao sair por cima (loop).
      final travel = (progress * p.speed * 10) % 1.0;
      final y = ((p.y0 - travel) % 1.0 + 1.0) % 1.0;

      // Leve oscilação horizontal tipo poeira flutuando.
      final drift = sin((progress * 2 * pi) + p.driftPhase) * p.driftAmplitude;
      final dx = p.x * size.width + drift;
      final dy = y * size.height;

      final color = palette[p.colorIndex];
      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 1.2);

      canvas.drawCircle(Offset(dx, dy), p.radius, paint);

      // Pequeno núcleo mais brilhante para dar profundidade.
      final corePaint = Paint()
        ..color = color.withValues(alpha: (p.opacity * 0.9).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(dx, dy), p.radius * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

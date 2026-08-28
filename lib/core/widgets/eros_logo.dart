/// `ErosLogo` — wordmark "EROS" desenhado em Flutter puro.
///
/// Não depende de nenhuma imagem externa: usa `ShaderMask` (mesmo
/// recurso já usado em `group_create_screen.dart`) para aplicar o
/// gradiente roxo/azul característico do app sobre um texto bold
/// com letter-spacing largo, mais um pequeno anel orbital abaixo
/// (referência sutil ao "planeta" das partículas de fundo).
import 'package:flutter/material.dart';

class ErosLogo extends StatelessWidget {
  const ErosLogo({
    super.key,
    this.fontSize = 64,
    this.showOrbit = true,
  });

  final double fontSize;
  final bool showOrbit;

  static const List<Color> _gradientColors = <Color>[
    Color(0xFF8A6CFF), // roxo claro (destaque)
    Color(0xFF6C4DFF), // roxo/azul (accent do app)
    Color(0xFF3B2A8C), // roxo-azulado profundo
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showOrbit) ...<Widget>[
          SizedBox(
            width: fontSize * 0.9,
            height: fontSize * 0.9,
            child: CustomPaint(painter: _OrbitPainter()),
          ),
          SizedBox(height: fontSize * 0.18),
        ],
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ).createShader(bounds),
          child: Text(
            'EROS',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: fontSize * 0.12,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pequeno "planeta com anel orbital" — um núcleo brilhante com um
/// anel elíptico inclinado ao redor, ecoando a estética de
/// poeira estelar do `ParticleBackground`.
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.width * 0.16;

    // Brilho externo (glow).
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF8A6CFF).withValues(alpha: 0.55),
          const Color(0xFF8A6CFF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 3));
    canvas.drawCircle(center, coreRadius * 3, glowPaint);

    // Anel orbital elíptico, levemente inclinado.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height * 0.34,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF3B2A8C),
          Color(0xFF8A6CFF),
          Color(0xFF6C4DFF),
        ],
      ).createShader(ringRect);
    canvas.drawOval(ringRect, ringPaint);
    canvas.restore();

    // Núcleo sólido central.
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFF8A6CFF),
          const Color(0xFF2A1B6E),
        ],
        stops: const <double>[0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
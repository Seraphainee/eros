/// `AppAvatar` — avatar circular padrão do app.
///
/// Mostra `photoUrl` se existir, senão as iniciais do nome em
/// fundo colorido gerado pelo `hashCode` do uid.
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.uid,
    this.size = 40,
  });

  final String name;
  final String? photoUrl;
  final String? uid;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color get _color {
    if (uid == null) return const Color(0xFF7C4DFF);
    final hue = (uid!.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.45).toColor();
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _color,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

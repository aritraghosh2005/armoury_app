import 'package:flutter/material.dart';
import '../core/ascii_art.dart';

/// Crisp, static rendering of the exact Orcus ASCII insignia.
///
/// Completely isolates the ASCII text inside a RepaintBoundary with zero
/// runtime CPU or GPU overhead, ensuring buttery smooth 60/120 FPS
/// performance for the utility app.
class AnimatedOrcusLogo extends StatelessWidget {
  final double fontSize;
  final Color color;
  final BoxFit fit;

  const AnimatedOrcusLogo({
    super.key,
    this.fontSize = 9.0,
    this.color = const Color(0xFFFFFFFF),
    this.fit = BoxFit.contain,
  });

  static final String _cleanedLogo = AsciiArt.orcusLogo
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .trimRight();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: fit,
      alignment: Alignment.center,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _cleanedLogo,
            softWrap: false,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              height: 1.15,
              letterSpacing: 0,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

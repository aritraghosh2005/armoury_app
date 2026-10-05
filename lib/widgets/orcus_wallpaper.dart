import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'animated_orcus_logo.dart';

/// Full-screen ambient terminal wallpaper featuring the hardware-accelerated
/// Orcus insignia with technical HUD calibration markings.
///
/// Fully responsive to Light / OLED Black theme palettes with high-contrast clarity.
class OrcusWallpaper extends StatelessWidget {
  final EdgeInsets? contentPadding;

  const OrcusWallpaper({super.key, this.contentPadding});

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight;

    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          color: AppColors.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _OrcusHudGridPainter(isLight: isLight)),
              Padding(
                padding: contentPadding ?? EdgeInsets.zero,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8.0,
                    ),
                    child: AnimatedOrcusLogo(
                      fontSize: 12.0,
                      fit: BoxFit.contain,
                      color: isLight
                          ? const Color(0x38000000) // Crisp, prominent dark ink watermark in light mode!
                          : const Color(0x40FFFFFF), // Subtle specular watermark in dark mode!
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints technical terminal coordinate grid lines and corner brackets.
class _OrcusHudGridPainter extends CustomPainter {
  final bool isLight;

  const _OrcusHudGridPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    const refW = 800.0;
    const refH = 1200.0;

    final scale = math.max(size.width / refW, size.height / refH);
    final dx = (size.width - refW * scale) / 2;
    final dy = (size.height - refH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final gridColor = isLight ? const Color(0x12000000) : const Color(0x08FFFFFF);
    final bracketColor = isLight ? const Color(0x35000000) : const Color(0x2EFFFFFF);
    final crossColor = isLight ? const Color(0x20000000) : const Color(0x18FFFFFF);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = 0; y <= refH; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(refW, y), gridPaint);
    }
    for (double x = 0; x <= refW; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, refH), gridPaint);
    }

    final bracketPaint = Paint()
      ..color = bracketColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final tl = Path()
      ..moveTo(24, 60)
      ..lineTo(24, 24)
      ..lineTo(60, 24);
    final tr = Path()
      ..moveTo(776, 60)
      ..lineTo(776, 24)
      ..lineTo(740, 24);
    final bl = Path()
      ..moveTo(24, 1140)
      ..lineTo(24, 1176)
      ..lineTo(60, 1176);
    final br = Path()
      ..moveTo(776, 1140)
      ..lineTo(776, 1176)
      ..lineTo(740, 1176);

    canvas.drawPath(tl, bracketPaint);
    canvas.drawPath(tr, bracketPaint);
    canvas.drawPath(bl, bracketPaint);
    canvas.drawPath(br, bracketPaint);

    final crossPaint = Paint()
      ..color = crossColor
      ..strokeWidth = 1.0;

    canvas.drawLine(const Offset(400, 30), const Offset(400, 90), crossPaint);
    canvas.drawLine(
      const Offset(400, 1110),
      const Offset(400, 1170),
      crossPaint,
    );
    canvas.drawLine(const Offset(30, 600), const Offset(90, 600), crossPaint);
    canvas.drawLine(const Offset(710, 600), const Offset(770, 600), crossPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrcusHudGridPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// A high-quality physical optical glass slab.
///
/// Simulates a floating, polished architectural glass sheet with:
/// - Crisp optical clarity in both OLED Pitch Black and High-Contrast Light mode
/// - Directional specular light rim along cut edges
/// - Double-beveled internal refraction rim
/// - Top-edge specular glint beam catching overhead light
/// - Soft diagonal surface reflection sheen
class OpticalGlassSlab extends ConsumerWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  const OpticalGlassSlab({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: isLight
              ? const [
                  // Clean architectural shadow for Light mode
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [
                  // Deep OLED pitch ambient shadow for Dark mode
                  BoxShadow(
                    color: Color(0xC0000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Color(0x18FFFFFF),
                    blurRadius: 3,
                    offset: Offset(0, -1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Optical Glass Substrate
              Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: isLight
                      ? const LinearGradient(
                          begin: Alignment(-0.8, -1.0),
                          end: Alignment(0.8, 1.0),
                          colors: [
                            Color(0xF2FFFFFF), // Pristine light plate glass top
                            Color(0xE8F8FAFC), // Crisp translucent body
                            Color(0xDEF1F5F9), // Subtle bottom plate depth
                          ],
                          stops: [0.0, 0.45, 1.0],
                        )
                      : const LinearGradient(
                          begin: Alignment(-0.8, -1.0),
                          end: Alignment(0.8, 1.0),
                          colors: [
                            Color(0x0CFFFFFF), // Subtle top specular gleam
                            Color(0x00FFFFFF), // Crystal clear body
                            Color(0x00FFFFFF), // Crystal clear body
                            Color(0x0A000000), // Ultra-subtle bottom plate depth
                          ],
                          stops: [0.0, 0.20, 0.70, 1.0],
                        ),
                ),
              ),

              // Optical surface refraction beam
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlassRefractionBeamPainter(
                        borderRadius: borderRadius,
                        isLight: isLight,
                      ),
                    ),
                  ),
                ),
              ),

              // The content placed inside the glass slab
              RepaintBoundary(child: child),

              // Precision specular glass bevel & edge highlights
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlassEdgeBevelPainter(
                        borderRadius: borderRadius,
                        isLight: isLight,
                      ),
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

/// Paints the subtle chromatic refraction beam across the glass plate.
class _GlassRefractionBeamPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isLight;

  const _GlassRefractionBeamPainter({
    required this.borderRadius,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -0.85),
        end: const Alignment(0.7, 0.85),
        colors: isLight
            ? const [
                Color(0x100F172A),
                Color(0x060F172A),
                Color(0x00FFFFFF),
              ]
            : const [
                Color(0x12FFFFFF),
                Color(0x08FFFFFF),
                Color(0x00FFFFFF),
              ],
        stops: const [0.0, 0.22, 0.58],
      ).createShader(rect);

    final rrect = borderRadius.toRRect(rect);
    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassRefractionBeamPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.isLight != isLight;
}

/// Paints the precision-beveled glass rim, top specular gleam, and physical glass refraction edges.
class _GlassEdgeBevelPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isLight;

  const _GlassEdgeBevelPainter({
    required this.borderRadius,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 1. Outer Polished Glass Bevel Border
    final outerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: const Alignment(-0.8, -1.0),
        end: const Alignment(0.8, 1.0),
        colors: isLight
            ? const [
                Color(0x600F172A), // Crisp slate top-left edge
                Color(0x350F172A), // Polished glass side
                Color(0x180F172A), // Subtle bottom-left edge
                Color(0x100F172A), // Ambient rim
              ]
            : const [
                Color(0x95FFFFFF), // Brilliant specular edge at top-left
                Color(0x50FFFFFF), // Polished glass side edge
                Color(0x20FFFFFF), // Bottom-left edge
                Color(0x18FFFFFF), // Bottom-right ambient rim
              ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, outerBorderPaint);

    // 2. Optical Prism Refraction Rim
    if (rect.width > 24 && rect.height > 24) {
      final causticPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [
                  Color(0x1A0F172A),
                  Color(0x0A0F172A),
                  Color(0x00FFFFFF),
                ]
              : const [
                  Color(0x28FFFFFF),
                  Color(0x10FFFFFF),
                  Color(0x00FFFFFF),
                ],
          stops: const [0.0, 0.25, 0.65],
        ).createShader(rect);

      canvas.drawRRect(borderRadius.toRRect(rect.deflate(1.2)), causticPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassEdgeBevelPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.isLight != isLight;
}

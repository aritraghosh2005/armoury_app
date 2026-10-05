import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// Fullscreen tactical pixel / block wavefront transition overlay.
///
/// Captures a snapshot of the current screen, switches the app theme immediately,
/// and animates a radial pixelated block wavefront outward from [origin].
///
/// Outside the wavefront, the old screen snapshot remains visible. Inside the
/// wavefront, pixel blocks shrink and dissolve, revealing the actual live new theme
/// screen underneath in coordinated pixel blocks with monochrome black-grey-white
/// dither highlights and zero external colors.
class PixelThemeTransition {
  static final GlobalKey screenKey = GlobalKey();
  static bool _isRunning = false;

  /// Launches the radial pixel transition from [origin] (e.g. button center).
  static Future<void> run(
    BuildContext context, {
    required WidgetRef ref,
    Offset? origin,
    required bool toLight,
    Duration duration = const Duration(milliseconds: 1850),
    VoidCallback? onComplete,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    ui.Image? snapshot;
    try {
      final boundary = screenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && boundary.hasSize) {
        snapshot = await boundary.toImage(pixelRatio: dpr);
      }
    } catch (_) {
      snapshot = null;
    }

    // Fallback: If snapshot couldn't be captured, toggle immediately and complete
    if (snapshot == null) {
      ref.read(themeProvider.notifier).toggleTheme();
      HapticFeedback.selectionClick();
      _isRunning = false;
      onComplete?.call();
      return;
    }

    if (!context.mounted) {
      snapshot.dispose();
      _isRunning = false;
      onComplete?.call();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ref.read(themeProvider.notifier).toggleTheme();
      snapshot.dispose();
      _isRunning = false;
      onComplete?.call();
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final resolvedOrigin = origin ?? Offset(screenSize.width / 2, screenSize.height / 2);

    OverlayEntry? entry;

    void cleanup() {
      try {
        entry?.remove();
        entry = null;
      } catch (_) {}
      try {
        snapshot?.dispose();
        snapshot = null;
      } catch (_) {}
      _isRunning = false;
      onComplete?.call();
    }

    entry = OverlayEntry(
      builder: (ctx) => _PixelWaveOverlay(
        snapshot: snapshot!,
        origin: resolvedOrigin,
        toLight: toLight,
        duration: duration,
        onFirstFrame: () {
          // The overlay is now confirmed painted on screen showing the snapshot.
          // Safely toggle the theme underneath so the new theme is rendered beneath the overlay without flicker!
          ref.read(themeProvider.notifier).toggleTheme();
          HapticFeedback.selectionClick();
        },
        onFinished: cleanup,
      ),
    );

    overlay.insert(entry!);
  }

  /// Convenience method that resolves the global tap center from a widget's [BuildContext].
  static void runFromContext(
    BuildContext buttonContext, {
    required WidgetRef ref,
    required bool toLight,
    Duration duration = const Duration(milliseconds: 1850),
    VoidCallback? onComplete,
  }) {
    Offset? origin;
    try {
      final box = buttonContext.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(box.size.center(Offset.zero));
      }
    } catch (_) {}

    run(
      buttonContext,
      ref: ref,
      origin: origin,
      toLight: toLight,
      duration: duration,
      onComplete: onComplete,
    );
  }
}

class _PixelWaveOverlay extends StatefulWidget {
  final ui.Image snapshot;
  final Offset origin;
  final bool toLight;
  final Duration duration;
  final VoidCallback onFirstFrame;
  final VoidCallback onFinished;

  const _PixelWaveOverlay({
    required this.snapshot,
    required this.origin,
    required this.toLight,
    required this.duration,
    required this.onFirstFrame,
    required this.onFinished,
  });

  @override
  State<_PixelWaveOverlay> createState() => _PixelWaveOverlayState();
}

class _PixelWaveOverlayState extends State<_PixelWaveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isCleanedUp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });

    // Toggle theme only AFTER the overlay has rendered its initial frame on screen!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFirstFrame();
      _controller.forward();
    });
  }

  void _finish() {
    if (_isCleanedUp) return;
    _isCleanedUp = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _finish();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: PixelWavePainter(
              snapshot: widget.snapshot,
              progress: _animation.value,
              origin: widget.origin,
              toLight: widget.toLight,
            ),
          );
        },
      ),
    );
  }
}

class PixelWavePainter extends CustomPainter {
  final ui.Image? snapshot;
  final double progress;
  final Offset origin;
  final bool toLight;
  final double blockSize;
  final double bandWidth;

  PixelWavePainter({
    this.snapshot,
    required this.progress,
    required this.origin,
    required this.toLight,
    this.blockSize = 18.0,
    this.bandWidth = 140.0,
  });

  static double _hash(int x, int y) {
    int n = x * 374761393 + y * 668265263;
    n = (n ^ (n >> 13)) * 1274126177;
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) {
      if (snapshot != null) {
        canvas.drawImageRect(
          snapshot!,
          Rect.fromLTWH(0, 0, snapshot!.width.toDouble(), snapshot!.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      return;
    }

    // Corner distances to calculate max reach across entire display
    final d1 = (origin - Offset.zero).distance;
    final d2 = (origin - Offset(size.width, 0)).distance;
    final d3 = (origin - Offset(0, size.height)).distance;
    final d4 = (origin - Offset(size.width, size.height)).distance;
    final maxRadius = math.max(math.max(d1, d2), math.max(d3, d4));

    final totalTravel = maxRadius + bandWidth;
    final currentR = progress * totalTravel;

    // If completely finished, the whole screen is new theme -> nothing to draw from old
    if (currentR >= totalTravel) {
      return;
    }

    final cols = (size.width / blockSize).ceil();
    final rows = (size.height / blockSize).ceil();
    final half = blockSize / 2;

    if (snapshot != null) {
      final Path oldScreenPath = Path();
      final List<Rect> waveRects = [];
      final List<double> waveAlphas = [];
      final List<Rect> sparkRects = [];
      final List<Color> sparkColors = [];

      // Monochrome spectrum: black, dark charcoal, slate, silver, pure white
      const monochromeSpectrum = [
        Color(0xFF020406),
        Color(0xFF1E293B),
        Color(0xFF475569),
        Color(0xFF94A3B8),
        Color(0xFFE2E8F0),
        Color(0xFFFFFFFF),
      ];

      for (int r = 0; r < rows; r++) {
        final y = r * blockSize;
        final centerY = y + half;

        for (int c = 0; c < cols; c++) {
          final x = c * blockSize;
          final centerX = x + half;

          final dx = centerX - origin.dx;
          final dy = centerY - origin.dy;
          final dist = math.sqrt(dx * dx + dy * dy);

          // Deterministic hash jitter for pixel block dispersion
          final jitter = (_hash(c, r) - 0.5) * bandWidth * 0.90;
          final effDist = dist + jitter;

          if (effDist > currentR) {
            // Wave hasn't arrived -> keep full old screen block
            oldScreenPath.addRect(Rect.fromLTWH(x, y, blockSize, blockSize));
          } else if (effDist > currentR - bandWidth) {
            // Inside active transition wavefront band:
            // Square blocks shrink smoothly toward center, revealing the new theme underneath around them
            final blockProgress = (currentR - effDist) / bandWidth;
            final scale = (1.0 - blockProgress).clamp(0.0, 1.0);

            if (scale > 0.05) {
              final inset = (blockSize * (1.0 - scale)) / 2;
              oldScreenPath.addRect(
                Rect.fromLTWH(x + inset, y + inset, blockSize * scale, blockSize * scale),
              );
            }

            // Monochrome outline along transitioning blocks
            final alpha = (1.0 - blockProgress).clamp(0.0, 1.0);
            if (alpha > 0.08) {
              waveRects.add(Rect.fromLTWH(x, y, blockSize, blockSize));
              waveAlphas.add(alpha);
            }

            // Monochrome crest pixel sparks (strictly within black - shades of black/grey - white)
            if ((currentR - effDist).abs() < 24.0 && _hash(c * 7, r * 13) > 0.70) {
              sparkRects.add(Rect.fromLTWH(x, y, blockSize, blockSize));
              final shadeIdx = (_hash(c, r) * monochromeSpectrum.length).floor().clamp(0, monochromeSpectrum.length - 1);
              sparkColors.add(toLight
                  ? monochromeSpectrum[monochromeSpectrum.length - 1 - shadeIdx]
                  : monochromeSpectrum[shadeIdx]);
            }
          }
          // If effDist <= currentR - bandWidth:
          // Wave has fully passed this block! Not added to oldScreenPath.
          // The live new theme screen renders directly underneath!
        }
      }

      // Draw the old screen image clipped to the un-transitioned pixel blocks
      final bounds = oldScreenPath.getBounds();
      if (!bounds.isEmpty) {
        canvas.save();
        canvas.clipPath(oldScreenPath);
        canvas.drawImageRect(
          snapshot!,
          Rect.fromLTWH(0, 0, snapshot!.width.toDouble(), snapshot!.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.none,
        );
        canvas.restore();
      }

      // Draw monochrome outline on active wavefront blocks (pure black/white spectrum)
      final Color strokeColor = toLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      for (int i = 0; i < waveRects.length; i++) {
        final outlinePaint = Paint()
          ..color = strokeColor.withValues(alpha: waveAlphas[i] * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRect(waveRects[i], outlinePaint);
      }

      // Draw monochrome crest spark blocks
      for (int i = 0; i < sparkRects.length; i++) {
        final sparkPaint = Paint()
          ..color = sparkColors[i].withValues(alpha: 0.50)
          ..style = PaintingStyle.fill;
        canvas.drawRect(sparkRects[i], sparkPaint);
      }
    } else {
      // Fallback mode without snapshot (e.g. headless tests):
      final Color targetBg = toLight ? const Color(0xFFF8FAFC) : const Color(0xFF000000);
      final Color oldBg = toLight ? const Color(0xFF000000) : const Color(0xFFF8FAFC);

      final Paint submergedPaint = Paint()
        ..color = targetBg
        ..isAntiAlias = false
        ..style = PaintingStyle.fill;

      for (int r = 0; r < rows; r++) {
        final y = r * blockSize;
        final centerY = y + half;

        for (int c = 0; c < cols; c++) {
          final x = c * blockSize;
          final centerX = x + half;

          final dx = centerX - origin.dx;
          final dy = centerY - origin.dy;
          final dist = math.sqrt(dx * dx + dy * dy);

          final jitter = (_hash(c, r) - 0.5) * bandWidth * 0.90;
          final effDist = dist + jitter;

          if (effDist > currentR) continue;

          final cellRect = Rect.fromLTWH(x, y, blockSize, blockSize);

          if (effDist < currentR - bandWidth) {
            canvas.drawRect(cellRect, submergedPaint);
          } else {
            final t = ((currentR - effDist) / bandWidth).clamp(0.0, 1.0);
            final col = Color.lerp(oldBg, targetBg, t)!;
            final p = Paint()
              ..color = col
              ..isAntiAlias = false
              ..style = PaintingStyle.fill;
            canvas.drawRect(cellRect, p);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.toLight != toLight ||
        oldDelegate.snapshot != snapshot;
  }
}

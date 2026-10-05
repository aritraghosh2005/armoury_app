import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/tutorial_provider.dart';
import 'terminal_button.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  static const int _kTotalSteps = 3;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _kTotalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    ref.read(tutorialProvider.notifier).markCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. High-Density Frosted Optical Glass Backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.86),
              ),
            ),

            // 2. Scanline HUD Pattern
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScanlinePainter(),
                ),
              ),
            ),

            // 3. Central Responsive Tactical Glass Card
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      maxHeight: maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0D10),
                      border: Border.all(
                        color: const Color(0xFF333D47),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header HUD Status Bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF11161B),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFF333D47)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF55FF55),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SYS.TUTORIAL [ ${_currentStep + 1} / $_kTotalSteps ]',
                                    style: AppTypography.mono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _finish,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    '[✕ CLOSE]',
                                    style: AppTypography.mono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Scrollable Animated Visual & Description Deck
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _buildStepVisual(_currentStep),
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _buildStepDescription(_currentStep),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Navigation Control Deck
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF11161B),
                            border: Border(
                              top: BorderSide(color: Color(0xFF333D47)),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_currentStep > 0) ...[
                                TerminalButton(
                                  label: '<< PREV',
                                  compact: true,
                                  onPressed: _prevStep,
                                ),
                                const SizedBox(width: 8),
                              ],
                              TerminalButton(
                                label: 'SKIP',
                                compact: true,
                                onPressed: _finish,
                              ),
                              const Spacer(),
                              TerminalButton(
                                label: _currentStep == _kTotalSteps - 1
                                    ? 'ENTER ARMOURY >>'
                                    : 'NEXT >>',
                                compact: true,
                                variant: TerminalButtonVariant.primary,
                                onPressed: _nextStep,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepVisual(int step) {
    Key key = ValueKey(step);
    switch (step) {
      case 0:
        return Container(
          key: key,
          height: 75,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF040608),
            border: Border.all(color: const Color(0xFF222B35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HEADER BAR // TOP-RIGHT',
                    style: AppTypography.caption(color: Colors.white54),
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Color.lerp(Colors.white, const Color(0xFF55FF55), _pulseAnimation.value)!,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        '☼ / ☾',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'ONE-TAP INSTANT PALETTE SWITCH',
                style: AppTypography.caption(color: Colors.white70),
              ),
            ],
          ),
        );

      case 1:
        return Container(
          key: key,
          height: 75,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF040608),
            border: Border.all(color: const Color(0xFF222B35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '← SWIPE HORIZONTALLY TO CYCLE SPACES →',
                style: AppTypography.caption(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _spaceBadge('ARMOURY', active: true),
                  const Text('⇄', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  _spaceBadge('CRATE'),
                  const Text('⇄', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  _spaceBadge('TOOLKIT'),
                  const Text('⇄', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  _spaceBadge('CUPBOARD'),
                ],
              ),
            ],
          ),
        );

      case 2:
      default:
        return Container(
          key: key,
          height: 75,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF040608),
            border: Border.all(color: const Color(0xFF222B35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A21),
                  border: Border.all(color: Colors.white70),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 12, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'QUERY: STM32F401_',
                      style: AppTypography.mono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DOUBLE-TAP HEADER OR TAP [SEARCH_]',
                style: AppTypography.caption(color: Colors.white54),
              ),
            ],
          ),
        );
    }
  }

  Widget _spaceBadge(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        border: Border.all(color: active ? Colors.white : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white60,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildStepDescription(int step) {
    Key key = ValueKey('desc_$step');
    switch (step) {
      case 0:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '01 // THEME TOGGLE (TOP-RIGHT)',
              style: AppTypography.heading(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the [☼ LIGHT / ☾ OLED] button in the TOP-RIGHT corner of the header to switch between OLED Pitch Black and High-Contrast Light theme. Follows your device system theme by default.',
              style: AppTypography.body(color: Colors.white70),
            ),
          ],
        );

      case 1:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '02 // INFINITE SPACES NAVIGATION',
              style: AppTypography.heading(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Swipe horizontally across the glass viewport to switch spaces with infinite circular wrapping: Armoury -> Crate -> Toolkit -> Cupboard.',
              style: AppTypography.body(color: Colors.white70),
            ),
          ],
        );

      case 2:
      default:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '03 // INSTANT SEARCH HUD',
              style: AppTypography.heading(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'DOUBLE-TAP the top header or press [SEARCH_] to activate the real-time search deck across names, serials, and categories.',
              style: AppTypography.body(color: Colors.white70),
            ),
          ],
        );
    }
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0CFFFFFF)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

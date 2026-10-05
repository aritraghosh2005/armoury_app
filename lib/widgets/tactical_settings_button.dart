import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Innovative tactile cyber-morphing settings/home button.
///
/// Features a mechanical gear dial that rotates 180 degrees during transition,
/// morphing between a tactical gear wheel and a precision home aperture reticle
/// with interactive specular highlights and cyber-brackets.
class TacticalSettingsMorphButton extends StatefulWidget {
  final bool isConfigOpen;
  final Animation<double>? rotationAnimation;
  final VoidCallback onPressed;

  const TacticalSettingsMorphButton({
    super.key,
    required this.isConfigOpen,
    this.rotationAnimation,
    required this.onPressed,
  });

  @override
  State<TacticalSettingsMorphButton> createState() =>
      _TacticalSettingsMorphButtonState();
}

class _TacticalSettingsMorphButtonState
    extends State<TacticalSettingsMorphButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: widget.rotationAnimation ?? const AlwaysStoppedAnimation(0.0),
        builder: (context, _) {
          final progress =
              widget.rotationAnimation?.value ?? (widget.isConfigOpen ? 1.0 : 0.0);
          final angle = progress * math.pi;

          Color bg;
          Color border;
          Color fg;

          if (widget.isConfigOpen) {
            bg = _isPressed
                ? (isLight ? const Color(0xFFE2E8F0) : const Color(0x33FFFFFF))
                : (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF000000));
            border = isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
            fg = isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
          } else {
            bg = _isPressed
                ? (isLight ? const Color(0xFFE2E8F0) : const Color(0x33FFFFFF))
                : (isLight ? const Color(0x90FFFFFF) : const Color(0x90000000));
            border = isLight ? const Color(0xFFCBD5E1) : AppColors.borderSubtle;
            fg = AppColors.fg;
          }

          return Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: border,
                width: 1,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: ClipRect(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: angle,
                    child: Icon(
                      widget.isConfigOpen
                          ? Icons.home_outlined
                          : Icons.settings_outlined,
                      size: 15,
                      color: fg,
                    ),
                  ),
                  if (widget.isConfigOpen) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Opacity(
                        opacity: ((progress - 0.5) / 0.5).clamp(0.0, 1.0),
                        child: Text(
                          'ESC',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: AppTypography.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

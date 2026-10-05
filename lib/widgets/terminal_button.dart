import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'double_tap_search_scope.dart';

enum TerminalButtonVariant {
  primary, // Inverted: White bg, Black text
  secondary, // Outline: Black bg, White border & text
  subtle, // Dim: Black bg, Subtle grey border & dim text
  danger, // Depleted outline: Dark border & grey text
}

class TerminalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDoubleTap;
  final TerminalButtonVariant variant;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final Widget? icon;

  const TerminalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.onDoubleTap,
    this.variant = TerminalButtonVariant.secondary,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.compact = false,
    this.icon,
  });

  @override
  State<TerminalButton> createState() => _TerminalButtonState();
}

class _TerminalButtonState extends State<TerminalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    Color bg;
    Color fg;
    Color border;

    switch (widget.variant) {
      case TerminalButtonVariant.primary:
        bg = _isPressed ? AppColors.dim : AppColors.fg;
        fg = AppColors.bg;
        border = AppColors.fg;
        break;
      case TerminalButtonVariant.secondary:
        bg = _isPressed ? AppColors.cardBgHighlight : AppColors.bg;
        fg = isEnabled ? AppColors.fg : AppColors.dim;
        border = isEnabled ? AppColors.fg : AppColors.borderSubtle;
        break;
      case TerminalButtonVariant.subtle:
        bg = _isPressed ? AppColors.cardBgHighlight : AppColors.bg;
        fg = isEnabled ? AppColors.dim : AppColors.dimmer;
        border = AppColors.borderSubtle;
        break;
      case TerminalButtonVariant.danger:
        bg = _isPressed ? AppColors.purgeBgActive : AppColors.purgeBg;
        fg = isEnabled ? AppColors.purgeRed : AppColors.dimmer;
        border = isEnabled ? AppColors.purgeBorder : const Color(0xFF3B0000);
        break;
    }

    final hasLabel = widget.label.trim().isNotEmpty;
    final scopedDoubleTap = DoubleTapSearchScope.maybeOf(context);
    final displayText = widget.compact ? widget.label : '[ ${widget.label} ]';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      onDoubleTap: isEnabled
          ? (widget.onDoubleTap ?? scopedDoubleTap ?? widget.onPressed)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : widget.padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) widget.icon!,
            if (widget.icon != null && hasLabel) const SizedBox(width: 6),
            if (hasLabel)
              Flexible(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: fg,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

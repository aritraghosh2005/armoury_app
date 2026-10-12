import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'terminal_button.dart';

/// The main-screen settings control morphs into the Config escape control.
class TacticalSettingsButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double progress;

  const TacticalSettingsButton({
    super.key,
    required this.onPressed,
    required this.progress,
  });

  @override
  State<TacticalSettingsButton> createState() => _TacticalSettingsButtonState();
}

class _TacticalSettingsButtonState extends State<TacticalSettingsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight;
    final showEscape = widget.progress >= 0.55;

    return Align(
      alignment: showEscape ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        child: showEscape
            ? TerminalButton(
                key: const ValueKey('escape-settings'),
                label: 'ESC',
                icon: Icon(
                  Icons.cancel_outlined,
                  size: 16,
                  color: AppColors.fg,
                ),
                compact: true,
                onPressed: widget.onPressed,
              )
            : GestureDetector(
                key: const ValueKey('main-settings'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                onTap: widget.onPressed,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isPressed
                        ? (isLight
                              ? const Color(0xFFE2E8F0)
                              : const Color(0x33FFFFFF))
                        : (isLight
                              ? const Color(0x90FFFFFF)
                              : const Color(0x90000000)),
                    border: Border.all(
                      color: isLight
                          ? const Color(0xFFCBD5E1)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 15,
                    color: AppColors.fg,
                  ),
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/media_viewmodel.dart';
import 'terminal_button.dart';

class MediaPickerSheet extends ConsumerStatefulWidget {
  final Component component;

  const MediaPickerSheet({super.key, required this.component});

  static Future<void> show(
    BuildContext context, {
    required Component component,
  }) {
    final isLight = AppColors.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: isLight ? const Color(0x35000000) : const Color(0x90000000),
      builder: (_) => MediaPickerSheet(component: component),
    );
  }

  @override
  ConsumerState<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends ConsumerState<MediaPickerSheet> {
  Future<void> _handleCaptureCamera() async {
    try {
      final saved = await ref
          .read(mediaViewModelProvider.notifier)
          .capture(widget.component.id);
      if (saved && mounted) Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _handlePickGallery() async {
    try {
      final saved = await ref
          .read(mediaViewModelProvider.notifier)
          .pick(widget.component.id);
      if (saved && mounted) Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: Text(
          'MEDIA ATTACH FAILED',
          style: AppTypography.heading(color: AppColors.fg),
        ),
        content: Text(error, style: AppTypography.body(color: AppColors.dim)),
        actions: [
          TerminalButton(
            label: 'CLOSE',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(mediaViewModelProvider);
    final isLight = ref.watch(themeProvider);
    final systemBottom = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottom > 24.0;
    final bottomInset = isButtonNav
        ? systemBottom
        : (systemBottom > 0 ? systemBottom : 12.0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: isLight
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF606090D), // Smoked dark obsidian top
                    Color(0xFA020406), // Rich OLED dark crystal body
                    Color(0xFF000000), // Pure OLED black bottom
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
          border: Border(
            top: BorderSide(
              color: isLight ? const Color(0xFFCBD5E1) : const Color(0x70FFFFFF),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isLight ? const Color(0x20000000) : const Color(0x80000000),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '[ATTACH MEDIA // ${widget.component.id}]',
                    style: AppTypography.heading(color: AppColors.fg),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      '[✕]',
                      style: AppTypography.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Upload schematic or hardware photo for ${widget.component.name}',
                style: AppTypography.caption(color: AppColors.dim),
              ),
              const SizedBox(height: 16),

              if (mediaState.isLoading) ...[
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.fg,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mediaState.message,
                        style: AppTypography.caption(color: AppColors.fg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                TerminalButton(
                  label: '◉ CAPTURE WITH CAMERA (SAVE TO DCIM)',
                  variant: TerminalButtonVariant.primary,
                  onPressed: mediaState.isLoading ? null : _handleCaptureCamera,
                ),
                const SizedBox(height: 10),
                TerminalButton(
                  label: '↑ UPLOAD FROM GALLERY',
                  variant: TerminalButtonVariant.secondary,
                  onPressed: mediaState.isLoading ? null : _handlePickGallery,
                ),
                const SizedBox(height: 10),
                TerminalButton(
                  label: 'CANCEL',
                  variant: TerminalButtonVariant.subtle,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      );
    }
}

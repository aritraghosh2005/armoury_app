import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/backup_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import 'optical_glass_slab.dart';
import 'pixel_theme_transition.dart';
import 'terminal_button.dart';

/// Optical glass slab for configuration that slides in alongside the main content slab.
/// Displays settings controls (theme toggle, zip backup export/import, telemetry)
/// with an innovative morphing home return button in the top right.
class SettingsGlassPane extends ConsumerStatefulWidget {
  const SettingsGlassPane({super.key});

  @override
  ConsumerState<SettingsGlassPane> createState() => _SettingsGlassPaneState();
}

class _SettingsGlassPaneState extends ConsumerState<SettingsGlassPane> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _isError = false;
  bool _isSuccess = false;

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'PACKAGING DATA & OPENING FOLDER TREE...';
      _isError = false;
      _isSuccess = false;
    });
    HapticFeedback.lightImpact();

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.exportBackupWithPicker();

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        if (result.cancelled) {
          _statusMessage = '[ EXPORT CANCELLED: NO DIRECTORY SELECTED ]';
          _isSuccess = false;
          _isError = false;
        } else if (result.success) {
          _statusMessage =
              '✓ EXPORT COMPLETE\nSaved to: ${result.savedPath}\nSize: ${result.sizeFormatted} (${result.componentCount} items)';
          _isSuccess = true;
          _isError = false;
          HapticFeedback.heavyImpact();
        } else {
          _statusMessage = '✕ EXPORT FAILED: ${result.error}';
          _isError = true;
          _isSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _isError = true;
        _statusMessage = '✕ UNEXPECTED ERROR: $e';
      });
    }
  }

  Future<void> _handleImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 8),
            Text(
              'CONFIRM IMPORT',
              style: AppTypography.heading(color: AppColors.fg),
            ),
          ],
        ),
        content: Text(
          'This will overwrite existing inventory data and images with the archive contents.',
          style: AppTypography.body(color: AppColors.dim),
        ),
        actions: [
          TerminalButton(
            label: 'CANCEL',
            compact: true,
            variant: TerminalButtonVariant.subtle,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TerminalButton(
            label: 'CONTINUE >>',
            compact: true,
            variant: TerminalButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isImporting = true;
      _statusMessage = 'OPENING FOLDER TREE TO SELECT .ZIP...';
      _isError = false;
      _isSuccess = false;
    });
    HapticFeedback.lightImpact();

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.importBackupWithPicker(overwrite: true);

      if (!mounted) return;
      setState(() {
        _isImporting = false;
        if (result.cancelled) {
          _statusMessage = '[ IMPORT CANCELLED: NO FILE SELECTED ]';
          _isSuccess = false;
          _isError = false;
        } else if (result.success) {
          ref.invalidate(armouryViewModelProvider);
          _statusMessage =
              '✓ RESTORE SUCCESSFUL\nImported ${result.restoredCount} components from ${result.fileName}.';
          _isSuccess = true;
          _isError = false;
          HapticFeedback.heavyImpact();
        } else {
          _statusMessage = '✕ RESTORE FAILED: ${result.error}';
          _isError = true;
          _isSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _isError = true;
        _statusMessage = '✕ UNEXPECTED ERROR: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(themeProvider);
    final totalUnits = ref.watch(
      armouryViewModelProvider.select((state) => state.value?.totalUnits ?? 0),
    );
    final entryCount = ref.watch(
      armouryViewModelProvider.select(
        (state) => state.value?.items.length ?? 0,
      ),
    );

    return OpticalGlassSlab(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Header Bar: Config Label + Innovative Morphing Home Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.fg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONFIG',
                      style: AppTypography.heading(color: AppColors.fg),
                    ),
                  ],
                ),
                const SizedBox(width: 52, height: 30),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.dividerLine),
            const SizedBox(height: 12),

            // 2. Scrollable Body Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [


                    // Section 1: Display Theme Mode
                    _buildSectionCard(
                      title: 'DISPLAY THEME',
                      icon: Icons.brightness_6_outlined,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isLight ? 'LIGHT MODE' : 'DARK MODE',
                            style: AppTypography.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.fg,
                            ),
                          ),
                          Builder(
                            builder: (btnCtx) => SizedBox(
                              width: 36,
                              height: 36,
                              child: TerminalButton(
                                label: '',
                                icon: Icon(
                                  isLight
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  size: 18,
                                  color: AppColors.fg,
                                ),
                                padding: EdgeInsets.zero,
                                compact: true,
                                variant: TerminalButtonVariant.secondary,
                                onPressed: () {
                                  PixelThemeTransition.runFromContext(
                                    btnCtx,
                                    ref: ref,
                                    toLight: !isLight,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Backup & Restore
                    _buildSectionCard(
                      title: 'BACKUP & RESTORE',
                      icon: Icons.folder_zip_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Export
                          TerminalButton(
                            label: _isExporting
                                ? 'PACKAGING...'
                                : 'EXPORT BACKUP (.ZIP)',
                            compact: true,
                            variant: TerminalButtonVariant.primary,
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 13,
                            ),
                            onPressed: (_isExporting || _isImporting)
                                ? null
                                : _handleExport,
                          ),
                          const SizedBox(height: 8),

                          // Import
                          TerminalButton(
                            label: _isImporting
                                ? 'OPENING...'
                                : 'IMPORT BACKUP (.ZIP)',
                            compact: true,
                            variant: TerminalButtonVariant.secondary,
                            icon: const Icon(
                              Icons.file_download_outlined,
                              size: 13,
                            ),
                            onPressed: (_isExporting || _isImporting)
                                ? null
                                : _handleImport,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Telemetry
                    _buildSectionCard(
                      title: 'TELEMETRY',
                      icon: Icons.memory_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ENTRIES:',
                                style: AppTypography.caption(
                                  color: AppColors.dim,
                                ),
                              ),
                              Text(
                                '$entryCount',
                                style: AppTypography.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'UNITS:',
                                style: AppTypography.caption(
                                  color: AppColors.dim,
                                ),
                              ),
                              Text(
                                '$totalUnits',
                                style: AppTypography.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DATABASE:',
                                style: AppTypography.caption(
                                  color: AppColors.dim,
                                ),
                              ),
                              Text(
                                'SQLite 3',
                                style: AppTypography.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status / Feedback message (Highlighted B&W at bottom of config slab)
                    if (_statusMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isError
                              ? AppColors.purgeBg
                              : (_isSuccess
                                    ? (isLight
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0x22FFFFFF))
                                    : AppColors.cardBgElevated),
                          border: Border.all(
                            color: _isError
                                ? AppColors.purgeBorder
                                : (_isSuccess
                                      ? (isLight
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFFFFFFF))
                                      : AppColors.borderSubtle),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isExporting || _isImporting) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.fg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: AppTypography.mono(
                                  fontSize: 10,
                                  height: 1.4,
                                  fontWeight: _isSuccess
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _isError
                                      ? AppColors.purgeRed
                                      : AppColors.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.dim),
              const SizedBox(width: 5),
              Text(
                title,
                style: AppTypography.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

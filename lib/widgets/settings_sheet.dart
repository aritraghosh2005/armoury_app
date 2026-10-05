import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/backup_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import 'pixel_theme_transition.dart';
import 'terminal_button.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final isLight = AppColors.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: isLight ? const Color(0x35000000) : const Color(0x90000000),
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _isError = false;
  bool _isSuccess = false;

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'PACKAGING REPOSITORY & OPENING FOLDER TREE...';
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
          _statusMessage = '✓ EXPORT COMPLETE\nSaved to: ${result.savedPath}\nSize: ${result.sizeFormatted} (${result.componentCount} components)';
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
    // Show confirmation dialog before initiating file navigation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text(
              'CONFIRM IMPORT',
              style: AppTypography.heading(color: AppColors.fg),
            ),
          ],
        ),
        content: Text(
          'Restoring from a backup will replace current inventory items and local images with the contents of the archive.\n\nProceed to navigate storage and select your .zip backup?',
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
            label: 'BROWSE FOR .ZIP >>',
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
      _statusMessage = 'OPENING FOLDER TREE TO SELECT .ZIP ARCHIVE...';
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
          _statusMessage = '✓ RESTORE SUCCESSFUL\nImported ${result.restoredCount} components from ${result.fileName}.';
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
      armouryViewModelProvider.select((state) => state.value?.items.length ?? 0),
    );

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottom = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottom > 24.0;
    final navInset = isButtonNav ? systemBottom : (systemBottom > 0 ? systemBottom : 10.0);
    final bottomInset = keyboardInset > 0 ? keyboardInset + 8.0 : navInset + 10.0;

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
                    Color(0xF606090D),
                    Color(0xFA020406),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
          border: Border(
            top: BorderSide(
              color: isLight ? const Color(0xFFCBD5E1) : const Color(0x60FFFFFF),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isLight ? const Color(0x20000000) : const Color(0xDD000000),
              blurRadius: 36,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 14,
          left: 16,
          right: 16,
          bottom: bottomInset,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 16,
                      color: AppColors.fg,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SYSTEM SETTINGS // CONFIG',
                      style: AppTypography.heading(color: AppColors.fg),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '[✕]',
                      style: AppTypography.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status / Feedback Banner if active
                    if (_statusMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isError
                              ? AppColors.purgeBg
                              : (_isSuccess
                                  ? (isLight ? const Color(0xFFE2E8F0) : const Color(0x22FFFFFF))
                                  : AppColors.cardBgElevated),
                          border: Border.all(
                            color: _isError
                                ? AppColors.purgeBorder
                                : (_isSuccess
                                    ? (isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF))
                                    : AppColors.borderSubtle),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isExporting || _isImporting) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.fg),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: AppTypography.mono(
                                  fontSize: 11,
                                  fontWeight: _isSuccess ? FontWeight.bold : FontWeight.normal,
                                  color: _isError
                                      ? AppColors.purgeRed
                                      : AppColors.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Section 1: Display / Theme Settings
                    _buildSectionContainer(
                      title: 'DISPLAY THEME // MODE',
                      icon: Icons.brightness_6_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLight ? 'HIGH CONTRAST LIGHT' : 'DARK OLED MATRIX',
                                    style: AppTypography.mono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.fg,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isLight ? 'Daylight tactical terminal' : 'Low-light stealth matrix',
                                    style: AppTypography.caption(color: AppColors.dim),
                                  ),
                                ],
                              ),
                              Builder(
                                builder: (btnCtx) => TerminalButton(
                                  label: isLight ? 'SWITCH TO DARK [☾]' : 'SWITCH TO LIGHT [☼]',
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
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Backup & Restore (Folder tree navigation)
                    _buildSectionContainer(
                      title: 'REPOSITORY DATA // BACKUP & RESTORE',
                      icon: Icons.folder_zip_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Package all components, specifications, and local hardware images into a portable .zip archive, or restore from an existing archive.',
                            style: AppTypography.body(color: AppColors.dim),
                          ),
                          const SizedBox(height: 12),

                          // Export Action
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.file_upload_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'EXPORT REPOSITORY (.ZIP)',
                                      style: AppTypography.mono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fg,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bundles database and local images into a .zip. You can navigate the folder tree to choose the exact location and name to save.',
                                  style: AppTypography.caption(color: AppColors.dim),
                                ),
                                const SizedBox(height: 10),
                                TerminalButton(
                                  label: _isExporting ? 'PACKAGING & NAVIGATING...' : 'EXPORT TO LOCATION >>',
                                  variant: TerminalButtonVariant.primary,
                                  onPressed: (_isExporting || _isImporting) ? null : _handleExport,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Import Action
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.file_download_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'IMPORT REPOSITORY (.ZIP)',
                                      style: AppTypography.mono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fg,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Opens the folder tree to select an existing .zip backup from your device to restore components and hardware photos.',
                                  style: AppTypography.caption(color: AppColors.dim),
                                ),
                                const SizedBox(height: 10),
                                TerminalButton(
                                  label: _isImporting ? 'OPENING FILE TREE...' : 'SELECT .ZIP TO IMPORT >>',
                                  variant: TerminalButtonVariant.secondary,
                                  onPressed: (_isExporting || _isImporting) ? null : _handleImport,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 3: System Telemetry & Statistics
                    _buildSectionContainer(
                      title: 'SYSTEM TELEMETRY',
                      icon: Icons.memory_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL REPOSITORY ENTRIES:',
                                style: AppTypography.caption(color: AppColors.dim),
                              ),
                              Text(
                                '$entryCount',
                                style: AppTypography.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL PHYSICAL UNITS:',
                                style: AppTypography.caption(color: AppColors.dim),
                              ),
                              Text(
                                '$totalUnits',
                                style: AppTypography.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'STORAGE ENGINE:',
                                style: AppTypography.caption(color: AppColors.dim),
                              ),
                              Text(
                                'SQLite 3 (Encrypted Local DB)',
                                style: AppTypography.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.dim),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

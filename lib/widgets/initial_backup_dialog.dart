import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/backup_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import 'terminal_button.dart';

class InitialBackupDialog extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;

  const InitialBackupDialog({super.key, required this.onDismiss});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: InitialBackupDialog(onDismiss: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  @override
  ConsumerState<InitialBackupDialog> createState() => _InitialBackupDialogState();
}

class _InitialBackupDialogState extends ConsumerState<InitialBackupDialog> {
  final _pathController = TextEditingController();
  bool _isRestoring = false;
  String? _statusFeedback;
  bool _isError = false;
  bool _showCustomPathInput = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _restoreFile(File file) async {
    setState(() {
      _isRestoring = true;
      _statusFeedback = 'EXTRACTING & RESTORING ZIP ARCHIVE...';
      _isError = false;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final count = await service.restoreBackupFromZip(file, overwrite: true);
      ref.invalidate(armouryViewModelProvider);

      setState(() {
        _isRestoring = false;
        _statusFeedback = 'SUCCESS: $count ASSETS RESTORED FROM ZIP.';
      });
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        widget.onDismiss();
      }
    } catch (e) {
      setState(() {
        _isRestoring = false;
        _isError = true;
        _statusFeedback = 'RESTORE FAILED: $e';
      });
    }
  }

  Future<void> _browseAndRestore() async {
    setState(() {
      _isRestoring = true;
      _statusFeedback = 'OPENING FOLDER TREE TO SELECT .ZIP...';
      _isError = false;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.importBackupWithPicker(overwrite: true);

      if (!mounted) return;
      if (result.cancelled) {
        setState(() {
          _isRestoring = false;
          _statusFeedback = '[ SELECTION CANCELLED ]';
        });
        return;
      }

      if (result.success) {
        ref.invalidate(armouryViewModelProvider);
        setState(() {
          _isRestoring = false;
          _statusFeedback = 'SUCCESS: ${result.restoredCount} ASSETS RESTORED FROM ${result.fileName}.';
        });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onDismiss();
        }
      } else {
        setState(() {
          _isRestoring = false;
          _isError = true;
          _statusFeedback = 'RESTORE FAILED: ${result.error}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _isError = true;
        _statusFeedback = 'RESTORE FAILED: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(detectedBackupsProvider);

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_zip_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'LOCAL BACKUP DETECTED',
                      style: AppTypography.heading(color: AppColors.fg),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Text(
                    '[✕]',
                    style: AppTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Restore repository items, specs, and photos from a .zip backup stored on your device:',
                    style: AppTypography.body(color: AppColors.dim),
                  ),
                  const SizedBox(height: 14),

                  if (_statusFeedback != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isError ? AppColors.purgeBg : AppColors.cardBgElevated,
                        border: Border.all(
                          color: _isError ? AppColors.purgeBorder : AppColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        _statusFeedback!,
                        style: AppTypography.mono(
                          fontSize: 11,
                          color: _isError ? AppColors.purgeRed : AppColors.fg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  backupsAsync.when(
                    data: (backups) {
                      if (backups.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NO .ZIP BACKUPS FOUND IN DOWNLOADS',
                                style: AppTypography.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dim,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can enter a custom path below or start with an empty repository.',
                                style: AppTypography.caption(color: AppColors.dimmer),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOUND ${backups.length} BACKUP ARCHIVE(S) IN STORAGE:',
                            style: AppTypography.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.fg,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...backups.map((b) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.fileName,
                                            style: AppTypography.mono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.fg,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${b.sizeFormatted} · ${b.file.parent.path}',
                                            style: AppTypography.caption(color: AppColors.dim),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TerminalButton(
                                      label: _isRestoring ? 'RESTORING...' : 'RESTORE',
                                      compact: true,
                                      variant: TerminalButtonVariant.primary,
                                      onPressed: _isRestoring ? null : () => _restoreFile(b.file),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          '[ SCANNING LOCAL STORAGE FOR .ZIP BACKUPS... ]',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ),
                    error: (err, _) => Text(
                      'Error scanning storage: $err',
                      style: AppTypography.caption(color: AppColors.purgeRed),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TerminalButton(
                    label: '📁 BROWSE STORAGE FOLDER TREE FOR .ZIP',
                    variant: TerminalButtonVariant.primary,
                    onPressed: _isRestoring ? null : _browseAndRestore,
                  ),
                  const SizedBox(height: 8),

                  // Option to specify custom file path
                  if (!_showCustomPathInput)
                    TerminalButton(
                      label: '📂 ENTER EXACT FILE PATH MANUALLY',
                      variant: TerminalButtonVariant.subtle,
                      onPressed: () => setState(() => _showCustomPathInput = true),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ENTER EXACT ZIP PATH ON DEVICE:',
                            style: AppTypography.caption(color: AppColors.dim),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _pathController,
                            style: AppTypography.mono(color: AppColors.fg, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: '/storage/emulated/0/Download/backup.zip',
                              hintStyle: AppTypography.mono(color: AppColors.dimmer, fontSize: 11),
                              filled: true,
                              fillColor: AppColors.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: AppColors.borderSubtle),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TerminalButton(
                            label: 'LOAD AND RESTORE THIS FILE',
                            variant: TerminalButtonVariant.primary,
                            onPressed: () {
                              final text = _pathController.text.trim();
                              if (text.isEmpty) return;
                              final f = File(text);
                              if (!f.existsSync()) {
                                setState(() {
                                  _isError = true;
                                  _statusFeedback = 'FILE DOES NOT EXIST AT PATH: $text';
                                });
                                return;
                              }
                              _restoreFile(f);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer Action Deck
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TerminalButton(
                  label: 'REFRESH SCAN',
                  compact: true,
                  onPressed: () => ref.invalidate(detectedBackupsProvider),
                ),
                TerminalButton(
                  label: 'START WITH NEW EMPTY REPOSITORY >>',
                  compact: true,
                  variant: TerminalButtonVariant.primary,
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

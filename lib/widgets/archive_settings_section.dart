import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/viewmodels/archive_viewmodel.dart';
import '../providers/viewmodels/auth_viewmodel.dart';
import 'settings_section_card.dart';
import 'terminal_button.dart';

/// Archive-only presentation and action feedback, hosted inside the Config pane.
class ArchiveSettingsSection extends ConsumerStatefulWidget {
  const ArchiveSettingsSection({super.key});

  @override
  ConsumerState<ArchiveSettingsSection> createState() =>
      _ArchiveSettingsSectionState();
}

class _ArchiveSettingsSectionState
    extends ConsumerState<ArchiveSettingsSection> {
  String? _statusMessage;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveItemsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          title: 'DELETED COMPONENTS',
          icon: Icons.archive_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Deleted components stay here for up to 7 days. Restore them before they expire.',
                style: AppTypography.caption(color: AppColors.dim),
              ),
              const SizedBox(height: 10),
              archive.when(
                loading: () => Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LOADING ARCHIVE...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: AppColors.dim),
                      ),
                    ),
                  ],
                ),
                error: (_, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARCHIVE COULD NOT BE LOADED.',
                      style: AppTypography.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your connection and try again.',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                    const SizedBox(height: 8),
                    TerminalButton(
                      label: 'RETRY',
                      compact: true,
                      onPressed: () => ref.invalidate(archiveItemsProvider),
                    ),
                  ],
                ),
                data: (items) => items.isEmpty
                    ? Text(
                        'ARCHIVE IS EMPTY. Deleted components will appear here when archived.',
                        style: AppTypography.caption(color: AppColors.dim),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < items.length;
                            index++
                          ) ...[
                            if (index > 0) ...[
                              const SizedBox(height: 7),
                              Container(
                                height: 1,
                                color: AppColors.dividerLine,
                              ),
                              const SizedBox(height: 7),
                            ],
                            _buildArchivedItem(items[index]),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: AppTypography.caption(
              color: _isError ? AppColors.purgeRed : AppColors.fg,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArchivedItem(Map<String, dynamic> item) {
    final id = item['id'].toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item['name']?.toString() ?? 'Unnamed',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(fontSize: 10, color: AppColors.fg),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'QTY ${item['qty'] ?? 0}',
              style: AppTypography.mono(fontSize: 9, color: AppColors.fg),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (ref.watch(authViewModelProvider).canEdit)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TerminalButton(
                label: 'RESTORE',
                compact: true,
                onPressed: () => _archiveAction(
                  () => ref.read(archiveViewModelProvider).restore(id),
                ),
              ),
              const SizedBox(width: 6),
              TerminalButton(
                label: 'DELETE',
                compact: true,
                variant: TerminalButtonVariant.danger,
                onPressed: () => _archiveAction(
                  () =>
                      ref.read(archiveViewModelProvider).permanentlyDelete(id),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _archiveAction(Future<void> Function() action) async {
    setState(() {
      _statusMessage = 'UPDATING ARCHIVE...';
      _isError = false;
    });
    try {
      await action();
      if (mounted) setState(() => _statusMessage = 'ARCHIVE UPDATED');
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'ARCHIVE ACTION FAILED. CHECK YOUR CONNECTION AND TRY AGAIN.';
          _isError = true;
        });
      }
    }
  }
}

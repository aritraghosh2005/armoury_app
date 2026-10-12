import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/viewmodels/auth_viewmodel.dart';
import '../providers/viewmodels/search_viewmodel.dart';
import 'morphing_header.dart';
import 'terminal_button.dart';

/// The inventory header and its search/add actions, kept out of AppShell's
/// pane and navigation orchestration.
class AppShellHeader extends ConsumerWidget {
  final int currentIndex;
  final bool isSettingsOpen;
  final Animation<double> settingsAnimation;
  final VoidCallback onSearchPressed;
  final VoidCallback onAddPressed;

  const AppShellHeader({
    super.key,
    required this.currentIndex,
    required this.isSettingsOpen,
    required this.settingsAnimation,
    required this.onSearchPressed,
    required this.onAddPressed,
  });

  String _titleFor(int index) => switch (index) {
    1 => 'crate',
    2 => 'toolkit',
    3 => 'cupboard',
    _ => 'armoury',
  };

  String _countLabel(WidgetRef ref) {
    final namespace = switch (currentIndex) {
      1 => ComponentNamespace.crate,
      2 => ComponentNamespace.toolkit,
      3 => ComponentNamespace.cupboard,
      _ => null,
    };
    if (namespace == null) return 'TEAM ORCUS';
    final count = ref.watch(filteredComponentsProvider(namespace)).length;
    return '$count ITEMS';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(
      searchViewModelProvider.select((state) => state.isVisible),
    );
    final canEdit = ref.watch(
      authViewModelProvider.select((state) => state.canEdit),
    );
    final isSettingsActive = isSettingsOpen || settingsAnimation.value > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: AppColors.dividerLine)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: isSettingsActive ? null : onSearchPressed,
                  child: MorphingAsciiHeader(title: _titleFor(currentIndex)),
                ),
              ),
              const SizedBox(width: 38),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: isSettingsActive ? null : onSearchPressed,
                  child: MorphingText(
                    text: _countLabel(ref),
                    style: AppTypography.heading(color: AppColors.fg),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TerminalButton(
                    label: search ? 'SEARCHING' : 'SEARCH_',
                    compact: true,
                    onPressed: isSettingsActive ? null : onSearchPressed,
                    onDoubleTap: isSettingsActive ? null : onSearchPressed,
                  ),
                  const SizedBox(width: 6),
                  if (canEdit)
                    TerminalButton(
                      label: '+ ADD',
                      compact: true,
                      variant: TerminalButtonVariant.primary,
                      onPressed: onAddPressed,
                      onDoubleTap: isSettingsActive ? null : onSearchPressed,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

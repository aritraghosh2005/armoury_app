import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../providers/backup_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import '../providers/viewmodels/auth_viewmodel.dart';
import '../providers/viewmodels/audit_viewmodel.dart';
import '../providers/viewmodels/admin_viewmodel.dart';
import 'optical_glass_slab.dart';
import 'pixel_theme_transition.dart';
import 'morphing_header.dart';
import 'terminal_button.dart';
import 'settings_section_card.dart';
import 'archive_settings_section.dart';

/// Optical glass slab for configuration that slides in alongside the main content slab.
/// Displays settings controls (theme toggle, zip backup export/import, telemetry)
/// with fixed-height pane headers and a minimal subview back control.
class SettingsGlassPane extends ConsumerStatefulWidget {
  final bool isArchiveOpen;
  final VoidCallback onOpenArchive;
  final VoidCallback onCloseArchive;
  final bool isAdminOpen;
  final VoidCallback onOpenAdmin;
  final VoidCallback onCloseAdmin;

  const SettingsGlassPane({
    super.key,
    this.isArchiveOpen = false,
    this.onOpenArchive = _noop,
    this.onCloseArchive = _noop,
    this.isAdminOpen = false,
    this.onOpenAdmin = _noop,
    this.onCloseAdmin = _noop,
  });
  static void _noop() {}

  @override
  ConsumerState<SettingsGlassPane> createState() => _SettingsGlassPaneState();
}

class _SettingsGlassPaneState extends ConsumerState<SettingsGlassPane> {
  String _localAuditTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }

  bool _isExporting = false;
  String? _statusMessage;
  bool _isError = false;
  bool _isSuccess = false;

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'PREPARING INVENTORY & PHOTOS...';
      _isError = false;
      _isSuccess = false;
    });
    HapticFeedback.lightImpact();

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.exportInventoryPackageWithPicker();

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        if (result.cancelled) {
          _statusMessage = '[ DOWNLOAD CANCELLED ]';
          _isSuccess = false;
          _isError = false;
        } else if (result.success) {
          _statusMessage =
              '✓ DOWNLOAD COMPLETE\nSaved to: ${result.savedPath}\n(${result.componentCount} items, ${result.imageCount} photos)';
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

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(themeProvider);
    final isAdmin = ref.watch(authViewModelProvider).isAdmin;
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
            // Keep the header height and title alignment invariant across panes.
            SizedBox(
              key: const ValueKey('settings-pane-header'),
              height: 36,
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    height: 36,
                    child: widget.isArchiveOpen || widget.isAdminOpen
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TerminalButton(
                              key: const ValueKey('back-to-config'),
                              label: '←',
                              compact: true,
                              onPressed: widget.isArchiveOpen
                                  ? widget.onCloseArchive
                                  : widget.onCloseAdmin,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
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
                            MorphingText(
                              text: widget.isArchiveOpen
                                  ? 'ARCHIVE'
                                  : widget.isAdminOpen
                                  ? 'ADMIN'
                                  : 'CONFIG',
                              style: AppTypography.heading(color: AppColors.fg),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.dividerLine),
            const SizedBox(height: 12),

            // 2. Scrollable Body Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  final openingSubview =
                      widget.isArchiveOpen || widget.isAdminOpen;
                  final activePageKey = ValueKey(
                    '${widget.isArchiveOpen}-${widget.isAdminOpen}',
                  );
                  final isEnteringPage = child.key == activePageKey;
                  final beginX = isEnteringPage
                      ? (openingSubview ? 1.0 : -1.0)
                      : (openingSubview ? -1.0 : 1.0);
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(beginX, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey(
                    '${widget.isArchiveOpen}-${widget.isAdminOpen}',
                  ),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: widget.isArchiveOpen || widget.isAdminOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.isArchiveOpen)
                              const ArchiveSettingsSection()
                            else
                              _buildAdminSection(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingsSectionCard(
                              title: 'MANAGEMENT',
                              icon: Icons.tune_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (isAdmin)
                                    TerminalButton(
                                      key: const ValueKey('open-admin'),
                                      label: 'ADMIN',
                                      compact: true,
                                      onPressed: widget.onOpenAdmin,
                                    ),
                                  if (isAdmin) const SizedBox(height: 8),
                                  TerminalButton(
                                    key: const ValueKey('open-archive'),
                                    label: 'ARCHIVE',
                                    compact: true,
                                    onPressed: widget.onOpenArchive,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Section 1: Display Theme Mode
                            SettingsSectionCard(
                              title: 'DISPLAY THEME',
                              icon: Icons.brightness_6_outlined,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        variant:
                                            TerminalButtonVariant.secondary,
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

                            SettingsSectionCard(
                              title: 'GOOGLE DEVICE',
                              icon: Icons.devices_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    ref.watch(authViewModelProvider).email ??
                                        'NOT REGISTERED · LOCAL OFFLINE MODE',
                                    style: AppTypography.caption(
                                      color: AppColors.dim,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TerminalButton(
                                    label:
                                        ref
                                            .watch(authViewModelProvider)
                                            .isLoading
                                        ? 'CONNECTING...'
                                        : ref
                                              .watch(authViewModelProvider)
                                              .isAuthenticated
                                        ? 'SIGN OUT'
                                        : 'LOGIN REQUIRED',
                                    compact: true,
                                    onPressed:
                                        ref
                                            .watch(authViewModelProvider)
                                            .isLoading
                                        ? null
                                        : ref
                                              .watch(authViewModelProvider)
                                              .isAuthenticated
                                        ? () => ref
                                              .read(
                                                authViewModelProvider.notifier,
                                              )
                                              .signOut()
                                        : null,
                                  ),
                                  if (ref.watch(authViewModelProvider).error !=
                                      null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      ref.watch(authViewModelProvider).error!,
                                      style: AppTypography.caption(
                                        color: AppColors.purgeRed,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (ref
                                .watch(authViewModelProvider)
                                .isAuthenticated) ...[
                              SettingsSectionCard(
                                title: 'RECENT ACTIVITY',
                                icon: Icons.history_outlined,
                                child: ref
                                    .watch(auditEventsProvider)
                                    .when(
                                      loading: () => Text(
                                        'LOADING ACTIVITY...',
                                        style: AppTypography.caption(
                                          color: AppColors.dim,
                                        ),
                                      ),
                                      error: (_, _) => Text(
                                        'ACTIVITY UNAVAILABLE',
                                        style: AppTypography.caption(
                                          color: AppColors.dim,
                                        ),
                                      ),
                                      data: (events) => events.isEmpty
                                          ? Text(
                                              'NO SHARED CHANGES YET',
                                              style: AppTypography.caption(
                                                color: AppColors.dim,
                                              ),
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                for (final event in events.take(
                                                  8,
                                                ))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '${event['action']?.toString().toUpperCase() ?? 'CHANGE'} · ${event['componentName'] ?? 'ITEM'}',
                                                          style:
                                                              AppTypography.caption(
                                                                color: AppColors
                                                                    .fg,
                                                              ),
                                                        ),
                                                        Text(
                                                          '${event['displayName'] ?? event['email']} · ${event['deviceName']} · ${_localAuditTime(event['occurredAt'])}',
                                                          style:
                                                              AppTypography.caption(
                                                                color: AppColors
                                                                    .dim,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                TerminalButton(
                                                  label: 'REFRESH ACTIVITY',
                                                  compact: true,
                                                  onPressed: () =>
                                                      ref.invalidate(
                                                        auditEventsProvider,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Section 2: Backup & Restore
                            SettingsSectionCard(
                              title: 'INVENTORY LIST',
                              icon: Icons.download_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Download the active inventory as a ZIP containing a CSV list and its photos.',
                                    style: AppTypography.caption(
                                      color: AppColors.dim,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Export
                                  TerminalButton(
                                    label: _isExporting
                                        ? 'PREPARING...'
                                        : 'DOWNLOAD INVENTORY + PHOTOS (.ZIP)',
                                    compact: true,
                                    variant: TerminalButtonVariant.primary,
                                    icon: const Icon(
                                      Icons.file_upload_outlined,
                                      size: 13,
                                    ),
                                    onPressed: _isExporting
                                        ? null
                                        : _handleExport,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Section 3: Telemetry
                            SettingsSectionCard(
                              title: 'TELEMETRY',
                              icon: Icons.memory_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                    if (_isExporting) ...[
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 4,
                              ),
                              child: Center(
                                child: Text(
                                  'j0K3r',
                                  style: AppTypography.caption(
                                    color: AppColors.dimmer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    final users = ref.watch(adminUsersProvider);
    final audit = ref.watch(adminAuditProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          title: 'ACCESS APPROVAL',
          icon: Icons.admin_panel_settings_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Approve accounts and assign VIEW or VIEW & EDIT access.',
                style: AppTypography.caption(color: AppColors.dim),
              ),
              const SizedBox(height: 10),
              users.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(
                  'USER LIST UNAVAILABLE. CHECK CONNECTION AND RETRY.',
                  style: AppTypography.caption(color: AppColors.purgeRed),
                ),
                data: (items) => items.isEmpty
                    ? Text(
                        'NO REGISTERED ACCOUNTS.',
                        style: AppTypography.caption(color: AppColors.dim),
                      )
                    : Column(
                        children: items.map((user) {
                          final status =
                              user['status']?.toString() ?? 'pending';
                          final role = user['role']?.toString() ?? 'viewer';
                          final name = user['displayName']?.toString().trim();
                          final email = user['email']?.toString() ?? '';
                          final devices =
                              (user['devices'] as List? ?? const []).length;
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.dividerLine),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  name == null || name.isEmpty ? email : name,
                                  style: AppTypography.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.fg,
                                  ),
                                ),
                                if (name != null && name.isNotEmpty)
                                  Text(
                                    email,
                                    style: AppTypography.caption(
                                      color: AppColors.dim,
                                    ),
                                  ),
                                Text(
                                  '${status.toUpperCase()} · ${role.toUpperCase()} · $devices DEVICE${devices == 1 ? '' : 'S'}',
                                  style: AppTypography.caption(
                                    color: AppColors.dim,
                                  ),
                                ),
                                Text(
                                  'LAST SEEN: ${_localAuditTime(user['lastSeenAt'])}',
                                  style: AppTypography.caption(
                                    color: AppColors.dim,
                                  ),
                                ),
                                if (status == 'pending') ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final grant in const [
                                        ('APPROVE VIEW', 'viewer'),
                                        ('APPROVE EDIT', 'editor'),
                                      ])
                                        TerminalButton(
                                          label: grant.$1,
                                          compact: true,
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(adminViewModelProvider)
                                                  .setAccess(
                                                    user,
                                                    'active',
                                                    grant.$2,
                                                  );
                                            } catch (e) {
                                              if (mounted) {
                                                setState(() {
                                                  _statusMessage =
                                                      'ACCESS UPDATE FAILED: $e';
                                                  _isError = true;
                                                });
                                              }
                                            }
                                          },
                                        ),
                                      TerminalButton(
                                        label: 'DENY',
                                        compact: true,
                                        variant: TerminalButtonVariant.danger,
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(adminViewModelProvider)
                                                .setAccess(
                                                  user,
                                                  'disabled',
                                                  'viewer',
                                                );
                                          } catch (e) {
                                            if (mounted) {
                                              setState(() {
                                                _statusMessage =
                                                    'ACCESS UPDATE FAILED: $e';
                                                _isError = true;
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (role == 'admin')
                                        Expanded(
                                          child: Text(
                                            'SOLE CONFIGURED ADMIN',
                                            style: AppTypography.caption(
                                              color: AppColors.dim,
                                            ),
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: DropdownButton<String>(
                                            value: role == 'editor'
                                                ? 'editor'
                                                : 'viewer',
                                            isExpanded: true,
                                            dropdownColor:
                                                AppColors.cardBgElevated,
                                            style: AppTypography.caption(
                                              color: AppColors.fg,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'viewer',
                                                child: Text('VIEW'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'editor',
                                                child: Text('VIEW & EDIT'),
                                              ),
                                            ],
                                            onChanged: (next) async {
                                              if (next == null ||
                                                  next == role) {
                                                return;
                                              }
                                              try {
                                                await ref
                                                    .read(
                                                      adminViewModelProvider,
                                                    )
                                                    .setAccess(
                                                      user,
                                                      'active',
                                                      next,
                                                    );
                                              } catch (e) {
                                                if (mounted) {
                                                  setState(() {
                                                    _statusMessage =
                                                        'ROLE UPDATE FAILED: $e';
                                                    _isError = true;
                                                  });
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      if (role != 'admin') ...[
                                        const SizedBox(width: 6),
                                        TerminalButton(
                                          label: status == 'disabled'
                                              ? 'ENABLE'
                                              : 'DISABLE',
                                          compact: true,
                                          variant: status == 'disabled'
                                              ? TerminalButtonVariant.secondary
                                              : TerminalButtonVariant.danger,
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(adminViewModelProvider)
                                                  .setAccess(
                                                    user,
                                                    status == 'disabled'
                                                        ? 'active'
                                                        : 'disabled',
                                                    role,
                                                  );
                                            } catch (e) {
                                              if (mounted) {
                                                setState(() {
                                                  _statusMessage =
                                                      'ACCESS UPDATE FAILED: $e';
                                                  _isError = true;
                                                });
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
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
        const SizedBox(height: 12),
        SettingsSectionCard(
          title: 'ACCESS HISTORY',
          icon: Icons.history,
          child: audit.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Text(
              'ACCESS HISTORY UNAVAILABLE.',
              style: AppTypography.caption(color: AppColors.dim),
            ),
            data: (events) => events.isEmpty
                ? Text(
                    'NO ADMIN ACTIONS RECORDED.',
                    style: AppTypography.caption(color: AppColors.dim),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: events
                        .map(
                          (event) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              '${_localAuditTime(event['occurredAt'])}  ${event['action']}\n${event['actorEmail']} → ${event['targetEmail']}',
                              style: AppTypography.caption(
                                color: AppColors.dim,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

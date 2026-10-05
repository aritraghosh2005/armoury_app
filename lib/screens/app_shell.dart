import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/tutorial_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import '../providers/viewmodels/search_viewmodel.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/double_tap_search_scope.dart';
import '../widgets/initial_backup_dialog.dart';
import '../widgets/morphing_header.dart';
import '../widgets/new_component_sheet.dart';
import '../widgets/optical_glass_slab.dart';
import '../widgets/orcus_wallpaper.dart';
import '../widgets/pixel_theme_transition.dart';
import '../widgets/settings_glass_pane.dart';
import '../widgets/tactical_settings_button.dart';
import '../widgets/terminal_button.dart';
import '../widgets/top_search_bar.dart';
import '../widgets/tutorial_overlay.dart';
import 'home_screen.dart';
import 'space_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

const int _kTabCount = 4;
const int _kInitialPage = 1000 * _kTabCount; // 4000

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _currentPage = _kInitialPage;
  late final PageController _pageController;
  late final AnimationController _settingsAnimController;
  late final CurvedAnimation _curvedSettingsAnim;
  bool _isSettingsOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _kInitialPage);
    _settingsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _curvedSettingsAnim = CurvedAnimation(
      parent: _settingsAnimController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialBackupPrompt();
    });
  }

  void _toggleSettings() {
    HapticFeedback.lightImpact();
    if (_isSettingsOpen || _settingsAnimController.value > 0) {
      _closeSettings();
    } else {
      _openSettings();
    }
  }

  void _openSettings() {
    // Searchbar is deactivated when config screen is active -> close if open
    if (ref.read(searchViewModelProvider).isVisible) {
      ref.read(searchViewModelProvider.notifier).setVisible(false);
    }
    setState(() => _isSettingsOpen = true);
    _settingsAnimController.forward();
  }

  void _closeSettings() {
    _settingsAnimController.reverse().then((_) {
      if (mounted) setState(() => _isSettingsOpen = false);
    });
  }

  Future<void> _checkInitialBackupPrompt() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      var prompted = false;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        prompted = data['hasPromptedInitialBackup'] as bool? ?? false;
      }
      if (!prompted && mounted) {
        Map<String, dynamic> data = {};
        if (await file.exists()) {
          data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        }
        data['hasPromptedInitialBackup'] = true;
        await file.writeAsString(jsonEncode(data));

        if (mounted) {
          InitialBackupDialog.show(context);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _curvedSettingsAnim.dispose();
    _settingsAnimController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    final diff = index - _currentIndex;
    int pageDelta = diff;
    if (diff > 2) {
      pageDelta = diff - _kTabCount;
    } else if (diff < -2) {
      pageDelta = diff + _kTabCount;
    }
    final targetPage = _currentPage + pageDelta;
    _currentPage = targetPage;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onAddPressed() {
    final vm = ref.read(armouryViewModelProvider.notifier);
    final ns = _currentIndex == 1
        ? ComponentNamespace.crate
        : (_currentIndex == 2
              ? ComponentNamespace.toolkit
              : (_currentIndex == 3
                    ? ComponentNamespace.cupboard
                    : ComponentNamespace.crate));
    NewComponentSheet.show(
      context,
      defaultNamespace: ns,
      onRegister: vm.create,
    );
  }

  Widget _buildPage(int tab) {
    final isLight = ref.watch(themeProvider);
    switch (tab) {
      case 0:
        return _KeptAlive(
          key: ValueKey('home_$isLight'),
          child: const HomeScreen(),
        );
      case 1:
        return _KeptAlive(
          key: ValueKey('crate_$isLight'),
          child: const SpaceScreen(namespace: ComponentNamespace.crate),
        );
      case 2:
        return _KeptAlive(
          key: ValueKey('toolkit_$isLight'),
          child: const SpaceScreen(namespace: ComponentNamespace.toolkit),
        );
      case 3:
        return _KeptAlive(
          key: ValueKey('cupboard_$isLight'),
          child: const SpaceScreen(namespace: ComponentNamespace.cupboard),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(themeProvider);
    final topInset = MediaQuery.of(context).padding.top;
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottomPadding > 24.0;
    final navBottomInset = isButtonNav
        ? systemBottomPadding
        : (systemBottomPadding > 0 ? systemBottomPadding : 6.0);
    final totalNavBarHeight = 52.0 + navBottomInset;

    final hasSeenTutorial = ref.watch(tutorialProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isLight
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF000000),
        systemNavigationBarDividerColor: isLight
            ? const Color(0xFFCBD5E1)
            : Colors.transparent,
        systemNavigationBarIconBrightness: isLight
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.bg,
        body: RepaintBoundary(
          key: PixelThemeTransition.screenKey,
          child: AnimatedBuilder(
            animation: _curvedSettingsAnim,
            builder: (context, _) {
              final progress = _curvedSettingsAnim.value;
              final screenWidth = MediaQuery.of(context).size.width;
              const kMargin = 8.0;
              const kGap = 8.0;
              final availableWidth = screenWidth - (kMargin * 2);
              final configWidth = (availableWidth - kGap) * 0.65;
              final mainVisibleWidth = (availableWidth - kGap) * 0.35;

              // Main content slab scales down smoothly to 0.88 and translates left
              final mainScale = 1.0 - (0.12 * progress);
              final mainScaledWidth = availableWidth * mainScale;
              final mainTranslationX =
                  -((mainScaledWidth - mainVisibleWidth) * progress);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Fixed Orcus HUD Insignia Wallpaper
                  Positioned.fill(
                    child: OrcusWallpaper(
                      contentPadding: EdgeInsets.only(
                        top: topInset + 6,
                        bottom: totalNavBarHeight + 6,
                      ),
                    ),
                  ),

                  // 2. Main Content Optical Glass Slab (slides out and scales down to 35% view)
                  Positioned(
                    left: kMargin,
                    top: topInset + 6,
                    bottom: totalNavBarHeight + 6,
                    width: availableWidth,
                    child: DoubleTapSearchScope(
                      onDoubleTap: () {
                        if (!_isSettingsOpen && progress == 0) {
                          ref
                              .read(searchViewModelProvider.notifier)
                              .toggleSearch();
                        }
                      },
                      child: Transform.translate(
                        offset: Offset(mainTranslationX, 0),
                        child: Transform.scale(
                          scale: mainScale,
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                OpticalGlassSlab(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _AppShellHeader(
                                        currentIndex: _currentIndex,
                                        isSettingsOpen: _isSettingsOpen,
                                        settingsAnimation: _curvedSettingsAnim,
                                        onSearchPressed: () {
                                          if (_isSettingsOpen || progress > 0) {
                                            return;
                                          }
                                          ref
                                              .read(
                                                searchViewModelProvider
                                                    .notifier,
                                              )
                                              .toggleSearch();
                                        },
                                        onAddPressed: _onAddPressed,
                                      ),
                                      Expanded(
                                        child: PageView.builder(
                                          controller: _pageController,
                                          physics: progress > 0
                                              ? const NeverScrollableScrollPhysics()
                                              : const PageScrollPhysics(
                                                  parent:
                                                      BouncingScrollPhysics(),
                                                ),
                                          onPageChanged: (page) {
                                            _currentPage = page;
                                            final tabIndex =
                                                ((page % _kTabCount) +
                                                    _kTabCount) %
                                                _kTabCount;
                                            if (_currentIndex != tabIndex) {
                                              setState(
                                                () => _currentIndex = tabIndex,
                                              );
                                            }
                                          },
                                          itemBuilder: (context, index) {
                                            final tab =
                                                ((index % _kTabCount) +
                                                    _kTabCount) %
                                                _kTabCount;
                                            return _buildPage(tab);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // When settings is active, tapping the visible 35% main slab returns to 100%!
                                if (progress > 0.0)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _closeSettings,
                                      child: Container(
                                        color:
                                            (isLight
                                                    ? const Color(0x30FFFFFF)
                                                    : const Color(0x55000000))
                                                .withValues(
                                                  alpha: 0.35 * progress,
                                                ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Config Glass Slab (Optical glass slab sliding in from right to occupy 65%)
                  if (progress > 0.0 || _isSettingsOpen)
                    Positioned(
                      right: kMargin,
                      top: topInset + 6,
                      bottom: totalNavBarHeight + 6,
                      width: configWidth,
                      child: Transform.translate(
                        offset: Offset(
                          (1.0 - progress) * (configWidth + kMargin + 16),
                          0,
                        ),
                        child: SettingsGlassPane(),
                      ),
                    ),

                  // One control travels from the header to the shared pane divider.
                  Positioned(
                    left:
                        (screenWidth - kMargin - 14 - 30) * (1 - progress) +
                        (kMargin + mainVisibleWidth + (kGap - (30.0 + 22.0 * progress)) / 2) *
                            progress,
                    top: topInset + 16,
                    child: SizedBox(
                      width: 30.0 + 22.0 * progress,
                      height: 30,
                      child: TacticalSettingsMorphButton(
                        isConfigOpen: progress >= 0.5,
                        rotationAnimation: _curvedSettingsAnim,
                        onPressed: _toggleSettings,
                      ),
                    ),
                  ),

                  // 4. Top Search Bar Overlay (strictly inactive when config is active)
                  if (progress == 0.0 && !_isSettingsOpen)
                    const _SearchOverlay(),

                  // 5. Fixed Bottom Navigation Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: BottomNavBar(
                      currentIndex: _currentIndex,
                      onTabSelected: (tab) {
                        if (_isSettingsOpen) _closeSettings();
                        _onTabSelected(tab);
                      },
                    ),
                  ),

                  // 6. Tactical First-Launch Tutorial Overlay
                  if (!hasSeenTutorial) const TutorialOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppShellHeader extends ConsumerWidget {
  final int currentIndex;
  final bool isSettingsOpen;
  final Animation<double> settingsAnimation;
  final VoidCallback onSearchPressed;
  final VoidCallback onAddPressed;

  const _AppShellHeader({
    required this.currentIndex,
    required this.isSettingsOpen,
    required this.settingsAnimation,
    required this.onSearchPressed,
    required this.onAddPressed,
  });

  String _getTitle(int index) {
    switch (index) {
      case 1:
        return 'crate';
      case 2:
        return 'toolkit';
      case 3:
        return 'cupboard';
      case 0:
      default:
        return 'armoury';
    }
  }

  String _getLeftText(int index, WidgetRef ref) {
    switch (index) {
      case 1:
        final count = ref
            .watch(filteredComponentsProvider(ComponentNamespace.crate))
            .length;
        return '$count ITEMS';
      case 2:
        final count = ref
            .watch(filteredComponentsProvider(ComponentNamespace.toolkit))
            .length;
        return '$count ITEMS';
      case 3:
        final count = ref
            .watch(filteredComponentsProvider(ComponentNamespace.cupboard))
            .length;
        return '$count ITEMS';
      case 0:
      default:
        return 'TEAM ORCUS';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(
      searchViewModelProvider.select((s) => s.isVisible),
    );
    final title = _getTitle(currentIndex);
    final leftText = _getLeftText(currentIndex, ref);
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
          // 1. Header row reserves space for the traveling settings control.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: isSettingsActive ? null : onSearchPressed,
                  child: MorphingAsciiHeader(title: title),
                ),
              ),
              const SizedBox(width: 38),
            ],
          ),
          const SizedBox(height: 10),
          // 2. Action row with title area (double-tap toggles search) and constant search + add buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: isSettingsActive ? null : onSearchPressed,
                  child: MorphingText(
                    text: leftText,
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

class _SearchOverlay extends ConsumerWidget {
  const _SearchOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(
      searchViewModelProvider.select((state) => state.isVisible),
    );
    final query = ref.watch(
      searchViewModelProvider.select((state) => state.query),
    );
    final domain = ref.watch(
      searchViewModelProvider.select((state) => state.domain),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: TopSearchBar(
        visible: isVisible,
        query: query,
        onQueryChanged: (q) {
          ref.read(searchViewModelProvider.notifier).setQuery(q);
        },
        selectedDomain: domain,
        onDomainChanged: (d) {
          ref.read(searchViewModelProvider.notifier).setDomain(d);
        },
        onClose: () {
          ref.read(searchViewModelProvider.notifier).setVisible(false);
        },
      ),
    );
  }
}

class _KeptAlive extends ConsumerStatefulWidget {
  final Widget child;

  const _KeptAlive({super.key, required this.child});

  @override
  ConsumerState<_KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends ConsumerState<_KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(themeProvider);
    return widget.child;
  }
}

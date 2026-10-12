import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/tutorial_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import '../providers/viewmodels/search_viewmodel.dart';
import '../providers/viewmodels/archive_viewmodel.dart';
import '../providers/viewmodels/admin_viewmodel.dart';
import '../providers/viewmodels/auth_viewmodel.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_search_overlay.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/double_tap_search_scope.dart';
import '../widgets/new_component_sheet.dart';
import '../widgets/optical_glass_slab.dart';
import '../widgets/orcus_wallpaper.dart';
import '../widgets/kept_alive_page.dart';
import '../widgets/pixel_theme_transition.dart';
import '../widgets/settings_glass_pane.dart';
import '../widgets/tactical_settings_button.dart';
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
  bool _isArchiveOpen = false;
  bool _isAdminOpen = false;

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
  }

  void _toggleSettings() {
    HapticFeedback.lightImpact();
    if (_isArchiveOpen || _isAdminOpen) {
      setState(() {
        _isArchiveOpen = false;
        _isAdminOpen = false;
      });
      return;
    }
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
    setState(() {
      _isSettingsOpen = true;
      _isArchiveOpen = false;
      _isAdminOpen = false;
    });
    _settingsAnimController.forward();
  }

  void _closeSettings() {
    _isArchiveOpen = false;
    _isAdminOpen = false;
    _settingsAnimController.reverse().then((_) {
      if (mounted) setState(() => _isSettingsOpen = false);
    });
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
    if (!ref.read(authViewModelProvider).canEdit) return;
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
        return KeptAlivePage(
          key: ValueKey('home_$isLight'),
          child: const HomeScreen(),
        );
      case 1:
        return KeptAlivePage(
          key: ValueKey('crate_$isLight'),
          child: const SpaceScreen(namespace: ComponentNamespace.crate),
        );
      case 2:
        return KeptAlivePage(
          key: ValueKey('toolkit_$isLight'),
          child: const SpaceScreen(namespace: ComponentNamespace.toolkit),
        );
      case 3:
        return KeptAlivePage(
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
                                      AppShellHeader(
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: SettingsGlassPane(
                            isArchiveOpen: _isArchiveOpen,
                            isAdminOpen: _isAdminOpen,
                            onOpenArchive: () {
                              ref.invalidate(archiveItemsProvider);
                              setState(() {
                                _isArchiveOpen = true;
                                _isAdminOpen = false;
                              });
                            },
                            onCloseArchive: () =>
                                setState(() => _isArchiveOpen = false),
                            onOpenAdmin: () {
                              ref.invalidate(adminUsersProvider);
                              ref.invalidate(adminAuditProvider);
                              setState(() {
                                _isAdminOpen = true;
                                _isArchiveOpen = false;
                              });
                            },
                            onCloseAdmin: () =>
                                setState(() => _isAdminOpen = false),
                          ),
                        ),
                      ),
                    ),

                  // The control travels from the main screen's right edge to
                  // the left edge as the main slab moves aside.
                  Positioned(
                    left: Tween<double>(
                      begin: screenWidth - kMargin - 68,
                      end: kMargin,
                    ).transform(progress),
                    top: topInset + 16,
                    child: SizedBox(
                      width: 68,
                      height: 30,
                      child: TacticalSettingsButton(
                        progress: progress,
                        onPressed: _toggleSettings,
                      ),
                    ),
                  ),

                  // 4. Top Search Bar Overlay (strictly inactive when config is active)
                  if (progress == 0.0 && !_isSettingsOpen)
                    const AppShellSearchOverlay(),

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

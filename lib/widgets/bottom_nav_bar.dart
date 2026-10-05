import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/theme_provider.dart';

class NavTabItem {
  final String keyName;
  final String icon;
  final String label;

  const NavTabItem({
    required this.keyName,
    required this.icon,
    required this.label,
  });
}

const List<NavTabItem> appNavTabs = [
  NavTabItem(keyName: 'home', icon: '[⌂]', label: 'HOME'),
  NavTabItem(keyName: 'crate', icon: '[▣]', label: 'CRATE'),
  NavTabItem(keyName: 'toolkit', icon: '[⌧]', label: 'TOOLKIT'),
  NavTabItem(keyName: 'cupboard', icon: '[≡]', label: 'CUPBOARD'),
];

/// A high-quality optical glass bottom navigation bar.
class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottomPadding > 24.0;
    final bottomInset = isButtonNav
        ? systemBottomPadding
        : (systemBottomPadding > 0 ? systemBottomPadding : 6.0);

    final activeFg = isLight ? const Color(0xFF0F172A) : Colors.white;
    final inactiveFg = isLight ? const Color(0xFF475569) : const Color(0xFF888888);

    return Container(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF000000),
        boxShadow: [
          BoxShadow(
            color: isLight ? const Color(0x18000000) : const Color(0xDD000000),
            blurRadius: isLight ? 12 : 20,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: RepaintBoundary(
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
                      Color(0xFA020306),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
            border: Border(
              top: BorderSide(
                color: isLight ? const Color(0xFFCBD5E1) : const Color(0x50FFFFFF),
                width: 1.0,
              ),
            ),
          ),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: 52,
            child: Row(
              children: List.generate(appNavTabs.length, (index) {
                final tab = appNavTabs[index];
                final isActive = currentIndex == index;

                return Expanded(
                  child: InkWell(
                    onTap: () => onTabSelected(index),
                    splashColor: isLight ? const Color(0x12000000) : const Color(0x20FFFFFF),
                    highlightColor: isLight ? const Color(0x0A000000) : const Color(0x10FFFFFF),
                    child: Container(
                      color: isActive
                          ? (isLight ? const Color(0x0E000000) : const Color(0x14FFFFFF))
                          : Colors.transparent,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive)
                            Positioned(
                              top: 0,
                              left: 16,
                              right: 16,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: activeFg,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isLight
                                          ? const Color(0x28000000)
                                          : const Color(0x80FFFFFF),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tab.icon,
                                style: AppTypography.mono(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isActive ? activeFg : inactiveFg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab.label,
                                style: AppTypography.mono(
                                  fontSize: 9.5,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isActive ? activeFg : inactiveFg,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

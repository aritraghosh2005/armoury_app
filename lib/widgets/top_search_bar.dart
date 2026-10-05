import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/theme_provider.dart';

const List<String> searchDomains = [
  'ALL',
  'MECHANICAL',
  'ELECTRICAL',
  'OTHERS',
];

class TopSearchBar extends ConsumerStatefulWidget {
  final bool visible;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String selectedDomain;
  final ValueChanged<String> onDomainChanged;
  final VoidCallback onClose;

  const TopSearchBar({
    super.key,
    required this.visible,
    required this.query,
    required this.onQueryChanged,
    required this.selectedDomain,
    required this.onDomainChanged,
    required this.onClose,
  });

  @override
  ConsumerState<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends ConsumerState<TopSearchBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _keyboardWasVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textCtrl.text = widget.query;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    if (widget.visible) {
      _animCtrl.forward();
      _focusNode.requestFocus();
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      if (_keyboardWasVisible && !keyboardVisible && widget.visible) {
        widget.onClose();
      }
      _keyboardWasVisible = keyboardVisible;
    });
  }

  @override
  void didUpdateWidget(covariant TopSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _textCtrl.text) {
      _textCtrl.text = widget.query;
    }
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _animCtrl.forward();
        _focusNode.requestFocus();
      } else {
        _animCtrl.reverse();
        _focusNode.unfocus();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final isLight = ref.watch(themeProvider);

    return IgnorePointer(
      ignoring: !widget.visible,
      child: SlideTransition(
        position: _slideAnim,
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
                        Color(0xF606090D), // Smoked dark obsidian top
                        Color(0xFA020306), // Rich OLED dark crystal body
                        Color(0xFF000000), // Pure OLED black bottom
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
              border: Border(
                bottom: BorderSide(
                  color: isLight ? const Color(0xFFCBD5E1) : const Color(0x50FFFFFF),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight ? const Color(0x18000000) : const Color(0xDD000000),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
              padding: EdgeInsets.only(
                top: topInset + 8,
                left: 14,
                right: 14,
                bottom: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Input Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF1F5F9) : const Color(0x15FFFFFF),
                      border: Border.all(
                        color: isLight ? const Color(0xFFCBD5E1) : const Color(0x50FFFFFF),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'SEARCH_',
                          style: AppTypography.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _focusNode,
                            style: AppTypography.mono(
                              fontSize: 12.5,
                              color: AppColors.fg,
                            ),
                            decoration: InputDecoration(
                              hintText: 'name, specs, tags, location...',
                              hintStyle: AppTypography.mono(
                                fontSize: 12,
                                color: AppColors.dim,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                            ),
                            onChanged: widget.onQueryChanged,
                          ),
                        ),
                        if (widget.query.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () {
                              _textCtrl.clear();
                              widget.onQueryChanged('');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '[CLEAR]',
                                style: AppTypography.caption(
                                  color: AppColors.dim,
                                ),
                              ),
                            ),
                          ),
                        ],
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            padding: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
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
                  ),
                  const SizedBox(height: 10),

                  // Domain Filter Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: searchDomains.map((dom) {
                      final isSelected =
                          widget.selectedDomain.toUpperCase() == dom;
                      return GestureDetector(
                        onTap: () => widget.onDomainChanged(dom.toLowerCase()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.fg
                                : (isLight ? const Color(0xFFF1F5F9) : const Color(0x12FFFFFF)),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.fg
                                  : (isLight ? const Color(0xFFCBD5E1) : const Color(0x35FFFFFF)),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            '[$dom]',
                            style: AppTypography.mono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.bg : AppColors.fg,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
}

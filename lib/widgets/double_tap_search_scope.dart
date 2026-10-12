import 'package:flutter/widgets.dart';

/// Provides button-specific double-tap behavior and detects double taps on
/// otherwise unhandled inventory space. The translucent detector participates
/// in hit testing without blocking scrolling or child controls.
class DoubleTapSearchScope extends StatelessWidget {
  final VoidCallback onDoubleTap;
  final Widget child;

  const DoubleTapSearchScope({
    super.key,
    required this.onDoubleTap,
    required this.child,
  });

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_DoubleTapSearchInherited>()
      ?.onDoubleTap;

  @override
  Widget build(BuildContext context) => _DoubleTapSearchInherited(
    onDoubleTap: onDoubleTap,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTap,
      child: child,
    ),
  );
}

class _DoubleTapSearchInherited extends InheritedWidget {
  final VoidCallback onDoubleTap;
  const _DoubleTapSearchInherited({
    required this.onDoubleTap,
    required super.child,
  });

  @override
  bool updateShouldNotify(_DoubleTapSearchInherited oldWidget) =>
      onDoubleTap != oldWidget.onDoubleTap;
}

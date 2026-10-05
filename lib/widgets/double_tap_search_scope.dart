import 'package:flutter/widgets.dart';

class DoubleTapSearchScope extends InheritedWidget {
  final VoidCallback onDoubleTap;

  const DoubleTapSearchScope({
    super.key,
    required this.onDoubleTap,
    required super.child,
  });

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DoubleTapSearchScope>()
      ?.onDoubleTap;

  @override
  bool updateShouldNotify(DoubleTapSearchScope oldWidget) =>
      onDoubleTap != oldWidget.onDoubleTap;
}

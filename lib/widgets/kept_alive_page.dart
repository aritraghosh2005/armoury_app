import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

/// Keeps each inventory tab mounted while preserving theme transition rebuilds.
class KeptAlivePage extends ConsumerStatefulWidget {
  final Widget child;

  const KeptAlivePage({super.key, required this.child});

  @override
  ConsumerState<KeptAlivePage> createState() => _KeptAlivePageState();
}

class _KeptAlivePageState extends ConsumerState<KeptAlivePage>
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

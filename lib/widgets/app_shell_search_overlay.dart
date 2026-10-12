import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/viewmodels/search_viewmodel.dart';
import 'top_search_bar.dart';

/// Search controls displayed above the inventory while Config is closed.
class AppShellSearchOverlay extends ConsumerWidget {
  const AppShellSearchOverlay({super.key});

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
        onQueryChanged: ref.read(searchViewModelProvider.notifier).setQuery,
        selectedDomain: domain,
        onDomainChanged: ref.read(searchViewModelProvider.notifier).setDomain,
        onClose: () =>
            ref.read(searchViewModelProvider.notifier).setVisible(false),
      ),
    );
  }
}

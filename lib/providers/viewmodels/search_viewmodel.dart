import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/component.dart';
import 'armoury_viewmodel.dart';

final searchViewModelProvider = NotifierProvider<SearchViewModel, SearchState>(
  SearchViewModel.new,
);

final filteredComponentsProvider =
    Provider.family<List<Component>, ComponentNamespace?>((ref, namespace) {
      final items = ref.watch(
        armouryViewModelProvider.select(
          (value) => value.value?.items ?? const <Component>[],
        ),
      );
      final query = ref.watch(
        searchViewModelProvider.select(
          (state) => state.query.trim().toLowerCase(),
        ),
      );
      final domain = ref.watch(
        searchViewModelProvider.select(
          (state) => state.domain.trim().toLowerCase(),
        ),
      );
      return items
          .where((item) {
            if (namespace != null && item.namespace != namespace) return false;
            final category = item.category.toLowerCase();
            if (domain == 'others' &&
                (category == 'mechanical' || category == 'electrical')) {
              return false;
            }
            if (domain.isNotEmpty &&
                domain != 'all' &&
                domain != 'others' &&
                category != domain) {
              return false;
            }
            if (query.isEmpty) return true;
            return [
              item.name,
              item.id,
              item.desc,
              item.specs,
              item.location,
              item.category,
              item.subcategory,
              ...item.tags,
            ].any((value) => value.toLowerCase().contains(query));
          })
          .toList(growable: false);
    });

class SearchState {
  final String query;
  final String domain;
  final bool isVisible;

  const SearchState({
    this.query = '',
    this.domain = 'all',
    this.isVisible = false,
  });

  SearchState copyWith({String? query, String? domain, bool? isVisible}) =>
      SearchState(
        query: query ?? this.query,
        domain: domain ?? this.domain,
        isVisible: isVisible ?? this.isVisible,
      );
}

class SearchViewModel extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      state = state.copyWith(query: value);
    });
  }

  void setDomain(String value) => state = state.copyWith(domain: value);
  void setVisible(bool value) => state = state.copyWith(isVisible: value);
  void toggleSearch() => setVisible(!state.isVisible);
}

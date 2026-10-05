import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/component_dao.dart';
import '../../core/database/content_dao.dart';
import '../../core/database/database_provider.dart';
import '../../core/repositories/component_repository.dart';
import '../../core/repositories/i_component_repository.dart';
import '../../models/component.dart';

final databaseProvider = Provider<DatabaseProvider>(
  (ref) => DatabaseProvider(),
);

final componentDaoProvider = Provider<ComponentDao>(
  (ref) => ComponentDao(() => ref.watch(databaseProvider).database),
);

final contentDaoProvider = Provider<ContentDao>(
  (ref) => ContentDao(() => ref.watch(databaseProvider).database),
);

final componentRepositoryProvider = Provider<IComponentRepository>(
  (ref) => ComponentRepository(ref.watch(componentDaoProvider)),
);

final armouryViewModelProvider =
    AsyncNotifierProvider<ArmouryViewModel, ArmouryState>(ArmouryViewModel.new);

class ArmouryState {
  final List<Component> items;

  const ArmouryState({this.items = const []});

  int get totalUnits => items.fold(0, (sum, item) => sum + item.qty);
}

class ArmouryViewModel extends AsyncNotifier<ArmouryState> {
  IComponentRepository get _repository => ref.read(componentRepositoryProvider);

  @override
  Future<ArmouryState> build() async =>
      ArmouryState(items: await _repository.getAll());

  Future<void> create(Map<String, dynamic> data) async {
    final previous = state.value;
    try {
      final created = await _repository.create(data);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          ArmouryState(items: [created, ...current.items]),
        );
      }
    } catch (_) {
      if (previous != null) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<Component?> updateComponent(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final current = state.value;
    if (current == null) return null;
    final index = current.items.indexWhere((item) => item.id == id);
    if (index < 0) return null;

    final original = current.items[index];
    final optimistic = original.copyWith(
      name: changes['name']?.toString(),
      namespace: changes.containsKey('namespace')
          ? ComponentNamespace.fromString(changes['namespace']?.toString())
          : null,
      category: changes['category']?.toString(),
      subcategory: changes['subcategory']?.toString(),
      qty: changes.containsKey('qty') ? (changes['qty'] as num).toInt() : null,
      desc: changes['desc']?.toString(),
      specs: changes['specs']?.toString(),
      location: changes['location']?.toString(),
      image: changes['image']?.toString(),
      status: changes.containsKey('status')
          ? Component.fromJson({'status': changes['status']}).status
          : null,
      tags: changes['tags'] is List
          ? (changes['tags'] as List).map((tag) => tag.toString()).toList()
          : null,
    );
    _replaceItem(id, optimistic);
    try {
      final updated = await _repository.update(id, changes);
      _replaceItem(id, updated);
      return updated;
    } catch (_) {
      _replaceItem(id, original);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final current = state.value;
    if (current == null) return;
    final index = current.items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final removed = current.items[index];
    state = AsyncValue.data(
      ArmouryState(
        items: current.items
            .where((item) => item.id != id)
            .toList(growable: false),
      ),
    );
    try {
      if (!await _repository.delete(id)) throw StateError('Delete failed');
    } catch (_) {
      final latest = state.value?.items ?? current.items;
      final restored = [...latest, removed]
        ..sort((a, b) => b.updated.compareTo(a.updated));
      state = AsyncValue.data(ArmouryState(items: restored));
      rethrow;
    }
  }

  void _replaceItem(String id, Component replacement) {
    final current = state.value;
    if (current == null) return;
    final items = [...current.items];
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = replacement;
    state = AsyncValue.data(ArmouryState(items: items));
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/operation_id.dart';
import '../app_providers.dart';
import 'armoury_viewmodel.dart';

final archiveItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(backendApiProvider).getArchive();
});

final archiveViewModelProvider = Provider<ArchiveViewModel>((ref) {
  return ArchiveViewModel(ref);
});

class ArchiveViewModel {
  final Ref _ref;
  ArchiveViewModel(this._ref);

  Future<void> restore(String id) async {
    final api = _ref.read(backendApiProvider);
    final result = await api.restoreArchived(id, newOperationId());
    if (result['component'] is Map) {
      final component = Map<String, dynamic>.from(result['component'] as Map);
      if (component['image'] is String) {
        component['image'] = api.resolveImage(component['image'] as String);
      }
      result['component'] = component;
    }
    await _ref.read(componentDaoProvider).applyServerChange(result);
    _ref.invalidate(archiveItemsProvider);
    _ref.invalidate(armouryViewModelProvider);
  }

  Future<void> permanentlyDelete(String id) async {
    await _ref.read(backendApiProvider).permanentlyDeleteArchived(id);
    _ref.invalidate(archiveItemsProvider);
  }
}

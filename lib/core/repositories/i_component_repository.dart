import '../../models/component.dart';

abstract interface class IComponentRepository {
  Future<List<Component>> getAll();
  Future<List<Component>> getPage({required int offset, int limit = 50});
  Future<Component?> getById(String id);
  Future<Component> create(Map<String, dynamic> data);
  Future<Component> update(String id, Map<String, dynamic> changes);
  Future<bool> delete(String id);
}

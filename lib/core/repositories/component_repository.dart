import '../../models/component.dart';
import '../database/component_dao.dart';
import 'i_component_repository.dart';

class ComponentRepository implements IComponentRepository {
  final ComponentDao _dao;

  const ComponentRepository(this._dao);

  @override
  Future<List<Component>> getAll() => _dao.getAll();
  @override
  Future<List<Component>> getPage({required int offset, int limit = 50}) =>
      _dao.getPage(offset: offset, limit: limit);
  @override
  Future<Component?> getById(String id) => _dao.getById(id);
  @override
  Future<Component> create(Map<String, dynamic> data) => _dao.insert(data);
  @override
  Future<Component> update(String id, Map<String, dynamic> changes) =>
      _dao.update(id, changes);
  @override
  Future<bool> delete(String id) => _dao.delete(id);
}

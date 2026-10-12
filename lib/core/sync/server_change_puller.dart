import '../database/component_dao.dart';
import 'backend_api.dart';

/// Applies the durable server change feed to the local SQLite cache.
class ServerChangePuller {
  final ComponentDao _dao;
  final BackendApi _api;

  const ServerChangePuller(this._dao, this._api);

  Future<void> pullAll() async {
    var cursor = await _dao.getSyncCursor();
    while (true) {
      final response = await _api.changesSince(cursor);
      final changes = response['changes'];
      if (changes is! List || changes.isEmpty) return;
      for (final item in changes) {
        if (item is! Map) continue;
        final change = Map<String, dynamic>.from(item);
        if (change['deleted'] != true && change['component'] is Map) {
          final component = Map<String, dynamic>.from(
            change['component'] as Map,
          );
          if (component['image'] is String) {
            component['image'] = _api.resolveImage(component['image'] as String);
          }
          change['component'] = component;
        }
        await _dao.applyServerChange(change);
        final revision = (change['revision'] as num?)?.toInt() ?? cursor;
        if (revision > cursor) cursor = revision;
      }
      await _dao.setSyncCursor(cursor);
      if (response['hasMore'] != true) return;
    }
  }
}

import 'dart:convert';

import '../database/component_dao.dart';
import 'backend_api.dart';

/// Sends queued local writes in order and reconciles their server responses.
/// Network retries leave the current operation in SQLite for the next pass.
class PendingOperationPusher {
  final ComponentDao _dao;
  final BackendApi _api;

  const PendingOperationPusher(this._dao, this._api);

  Future<void> pushAll() async {
    while (true) {
      final pending = await _dao.getPendingSyncOperations();
      if (pending.isEmpty) return;
      final operation = pending.first;
      final operationId = operation['operation_id']!.toString();
      final componentId = operation['component_id']!.toString();
      final kind = operation['kind']!.toString();
      final payload =
          jsonDecode(operation['payload']!.toString()) as Map<String, dynamic>;
      final localImage = switch (kind) {
        'create' ||
        'restore' => (payload['component'] as Map?)?['image']?.toString(),
        'patch' => (payload['changes'] as Map?)?['image']?.toString(),
        _ => null,
      };

      try {
        final result = await _send(kind, componentId, operationId, payload);
        if (result == null) {
          await _dao.removePendingOperation(operationId);
          continue;
        }
        await _dao.removePendingOperation(operationId);
        await _applyResult(result, localImage);
      } on ArmouryRemoteException catch (error) {
        if (error.statusCode == 410) {
          await _dao.removePendingOperation(operationId);
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> _send(
    String kind,
    String componentId,
    String operationId,
    Map<String, dynamic> payload,
  ) async {
    switch (kind) {
      case 'create':
      case 'restore':
        final component = Map<String, dynamic>.from(
          payload['component'] as Map,
        );
        component['image'] = await _api.prepareImage(
          component['image']?.toString(),
          componentId: componentId,
          operationId: operationId,
        );
        payload['component'] = component;
        await _dao.updatePendingPayload(operationId, payload);
        return kind == 'create'
            ? _api.createComponent(componentId, component, operationId)
            : _api.restoreComponent(componentId, component, operationId);
      case 'patch':
        final changes = Map<String, dynamic>.from(payload['changes'] as Map);
        if (changes.containsKey('image')) {
          changes['image'] = await _api.prepareImage(
            changes['image']?.toString(),
            componentId: componentId,
            operationId: operationId,
          );
          payload['changes'] = changes;
          await _dao.updatePendingPayload(operationId, payload);
        }
        return _api.patchComponent(componentId, changes, operationId);
      case 'delete':
        return _api.deleteComponent(componentId, operationId);
      default:
        return null;
    }
  }

  Future<void> _applyResult(
    Map<String, dynamic> response,
    String? localImage,
  ) async {
    final normalized = Map<String, dynamic>.from(response);
    if (normalized['deleted'] != true && normalized['component'] is Map) {
      final component = Map<String, dynamic>.from(
        normalized['component'] as Map,
      );
      if (component['image'] is String) {
        component['image'] = _api.resolveImage(component['image'] as String);
      }
      normalized['component'] = component;
    }
    await _dao.applyServerChange(normalized, preservedLocalImage: localImage);
  }
}

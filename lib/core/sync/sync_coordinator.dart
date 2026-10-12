import 'dart:async';

import '../database/component_dao.dart';
import 'backend_api.dart';
import 'pending_operation_pusher.dart';
import 'server_change_puller.dart';

class SyncCoordinator {
  final ComponentDao _dao;
  final BackendApi _api;
  Timer? _timer;
  bool _running = false;
  Future<void> Function()? _onSynchronized;

  SyncCoordinator(this._dao, this._api);

  void start({Future<void> Function()? onSynchronized}) {
    if (onSynchronized != null) _onSynchronized = onSynchronized;
    if (!_api.isConfigured || _timer != null) return;
    unawaited(_syncAndNotify());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_syncAndNotify());
    });
  }

  Future<void> _syncAndNotify() async {
    await syncOnce();
    await _onSynchronized?.call();
  }

  Future<void> syncOnce() async {
    if (!_api.isConfigured || !_api.isAuthenticated || _running) return;
    _running = true;
    try {
      if (_api.canWrite) {
        await _dao.queueInitialSupabaseCatalogOnce(_api.syncNamespace);
        try {
          await PendingOperationPusher(_dao, _api).pushAll();
        } on ArmouryRemoteException catch (error) {
          if (error.code != '42501' || _api.canWrite) rethrow;
        }
      }
      await ServerChangePuller(_dao, _api).pullAll();
    } catch (_) {
      // Local writes stay queued. The next foreground interval/reopen retries.
    } finally {
      _running = false;
    }
  }

  void dispose() => _timer?.cancel();

  void stop() {
    _timer?.cancel();
    _timer = null;
    _onSynchronized = null;
  }
}

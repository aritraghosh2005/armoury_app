import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/component.dart';
import '../sync/operation_id.dart';

class ComponentDao {
  final Future<Database> Function() _database;
  String? _syncActorKey;

  ComponentDao(this._database);

  void setSyncActor(String? actorKey) => _syncActorKey = actorKey;

  Future<void> claimUnownedOperations(String actorKey) async {
    await (await _database()).update('sync_operations', {
      'actor_key': actorKey,
    }, where: 'actor_key IS NULL');
  }

  Future<String?> getSyncValue(String key) async {
    final rows = await (await _database()).query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> setSyncValue(String key, String value) async {
    await (await _database()).insert('sync_state', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> getOrCreateDeviceId({String? accountKey}) async {
    final db = await _database();
    final key = accountKey == null ? 'device_id' : 'device_id_$accountKey';
    final rows = await db.query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['value']!.toString();

    var id = newOperationId();
    if (accountKey != null) {
      final accountDevices = await db.query(
        'sync_state',
        columns: ['key'],
        where: "key LIKE 'device_id_%'",
        limit: 1,
      );
      final legacyDevice = accountDevices.isEmpty
          ? await db.query(
              'sync_state',
              columns: ['value'],
              where: 'key = ?',
              whereArgs: ['device_id'],
              limit: 1,
            )
          : const <Map<String, Object?>>[];
      if (legacyDevice.isNotEmpty) {
        id = legacyDevice.first['value']!.toString();
      }
    }
    await db.insert('sync_state', {
      'key': key,
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final stored = await db.query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    return stored.first['value']!.toString();
  }

  Future<List<Component>> getAll() async {
    final rows = await (await _database()).query(
      'components',
      orderBy: 'updated DESC, id DESC',
    );
    if (rows.length < 100) {
      return rows.map(_toComponent).toList(growable: false);
    }
    return compute(_decodeComponentRows, rows);
  }

  Future<List<Component>> getPage({required int offset, int limit = 50}) async {
    final rows = await (await _database()).query(
      'components',
      orderBy: 'updated DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_toComponent).toList(growable: false);
  }

  Future<bool> canSeedBundledInitialData() async {
    final db = await _database();
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
    if (await count('components') > 0 ||
        await count('sync_tombstones') > 0 ||
        await count('sync_versions') > 0 ||
        await count('sync_operations') > 0) {
      return false;
    }
    final cursor = await db.query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['server_cursor'],
      limit: 1,
    );
    return cursor.isEmpty ||
        (int.tryParse(cursor.first['value'].toString()) ?? 0) == 0;
  }

  Future<String?> getBundledInitialDataStatus() async {
    final rows = await (await _database()).query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['bundled_initial_data_status'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<bool> hasTombstone(String id) async =>
      (await (await _database()).query(
        'sync_tombstones',
        columns: ['component_id'],
        where: 'component_id = ?',
        whereArgs: [id],
        limit: 1,
      )).isNotEmpty;

  Future<void> setBundledInitialDataStatus(String status) async {
    await (await _database()).insert('sync_state', {
      'key': 'bundled_initial_data_status',
      'value': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Component?> getById(String id) async {
    final rows = await (await _database()).query(
      'components',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _toComponent(rows.first);
  }

  Future<Component> insert(Map<String, dynamic> data) async {
    final db = await _database();
    final id = data['id']?.toString().trim().isNotEmpty == true
        ? data['id'].toString()
        : newOperationId();
    final now = DateTime.now().toUtc().toIso8601String();
    final row = <String, dynamic>{
      'id': id,
      'namespace': _namespaceValue(data['namespace']),
      'category': data['category']?.toString() ?? 'Electrical',
      'subcategory': data['subcategory']?.toString() ?? '',
      'name': data['name']?.toString() ?? 'Unnamed',
      'qty': (data['qty'] as num?)?.toInt() ?? 1,
      'desc': data['desc']?.toString() ?? '',
      'pic': data['pic']?.toString() ?? '',
      'image': data['image']?.toString(),
      'location': data['location']?.toString() ?? '',
      'specs': data['specs']?.toString() ?? '',
      'status': data['status']?.toString() ?? 'available',
      'tags': jsonEncode(data['tags'] is List ? data['tags'] : const []),
      'created': data['created']?.toString() ?? now,
      'updated': now,
    };
    await db.transaction((txn) async {
      final deleted = await txn.query(
        'sync_tombstones',
        columns: ['component_id'],
        where: 'component_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (deleted.isNotEmpty) {
        throw StateError('Deleted component IDs cannot be reused');
      }
      await txn.insert(
        'components',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _enqueue(txn, id, 'create', {
        'component': _toComponent(row).toJson(),
      }, actorKey: _syncActorKey);
    });
    return _toComponent(row);
  }

  Future<Component> update(String id, Map<String, dynamic> changes) async {
    final db = await _database();
    final exists = await getById(id);
    if (exists == null) throw StateError('Component [$id] not found');
    final values = <String, Object?>{
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    const fields = [
      'name',
      'category',
      'subcategory',
      'qty',
      'desc',
      'specs',
      'location',
      'status',
      'image',
    ];
    for (final field in fields) {
      if (!changes.containsKey(field)) continue;
      values[field] = field == 'qty'
          ? (changes[field] as num).toInt()
          : changes[field]?.toString();
    }
    if (changes.containsKey('namespace')) {
      values['namespace'] = _namespaceValue(changes['namespace']);
    }
    if (changes.containsKey('tags')) {
      values['tags'] = jsonEncode(
        changes['tags'] is List ? changes['tags'] : const [],
      );
    }
    await db.transaction((txn) async {
      final deleted = await txn.query(
        'sync_tombstones',
        columns: ['component_id'],
        where: 'component_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (deleted.isNotEmpty) return;
      await txn.update('components', values, where: 'id = ?', whereArgs: [id]);
      await _enqueue(txn, id, 'patch', {
        'changes': changes,
      }, actorKey: _syncActorKey);
    });
    return await getById(id) ?? exists;
  }

  Future<bool> delete(String id) async {
    final db = await _database();
    return db.transaction((txn) async {
      final count = await txn.delete(
        'components',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count > 0) {
        await _enqueue(txn, id, 'delete', const {}, actorKey: _syncActorKey);
      }
      return count > 0;
    });
  }

  Future<void> queueInitialSupabaseCatalogOnce(String backendNamespace) async {
    final actorKey = _syncActorKey;
    if (actorKey == null || actorKey.isEmpty) return;
    final db = await _database();
    await db.transaction((txn) async {
      final markerKey = 'supabase_catalog_queued_$backendNamespace';
      final marker = await txn.query(
        'sync_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [markerKey],
        limit: 1,
      );
      if (marker.isNotEmpty) return;

      // Cursor and row revisions from the former API are unrelated to the new
      // Supabase revision stream. Keep tombstoned IDs but restart its ordering.
      await txn.insert('sync_state', {
        'key': 'server_cursor',
        'value': '0',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('sync_versions');
      await txn.update('sync_tombstones', {'revision': 0});

      final rows = await txn.query('components');
      for (final row in rows) {
        final component = _toComponent(row);
        final queued = await txn.query(
          'sync_operations',
          columns: ['queue_id'],
          where: 'component_id = ? AND actor_key = ? AND kind = ?',
          whereArgs: [component.id, actorKey, 'create'],
          limit: 1,
        );
        if (queued.isNotEmpty) continue;
        await _enqueue(txn, component.id, 'create', {
          'component': component.toJson(),
        }, actorKey: actorKey);
      }
      final tombstones = await txn.query(
        'sync_tombstones',
        columns: ['component_id'],
      );
      for (final tombstone in tombstones) {
        final id = tombstone['component_id']?.toString();
        if (id == null || id.isEmpty) continue;
        final queued = await txn.query(
          'sync_operations',
          columns: ['queue_id'],
          where: 'component_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (queued.isEmpty) {
          await _enqueue(txn, id, 'delete', const {}, actorKey: actorKey);
        }
      }
      await txn.insert('sync_state', {
        'key': markerKey,
        'value': '1',
      });
    });
  }

  static Future<void> enqueueRestoredState(
    DatabaseExecutor txn, {
    required List<Map<String, Object?>> previousRows,
    required List<Map<String, dynamic>> restoredRows,
    required bool overwrite,
    String? actorKey,
  }) async {
    if (overwrite) await txn.delete('sync_operations');
    final restoredIds = restoredRows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (overwrite) {
      for (final row in previousRows) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && !restoredIds.contains(id)) {
          await _enqueue(txn, id, 'delete', const {}, actorKey: actorKey);
        }
      }
    }
    for (final row in restoredRows) {
      final component = _toComponent(Map<String, Object?>.from(row)).toJson();
      if (component['id']?.toString().isNotEmpty != true) continue;
      await _enqueue(txn, component['id'].toString(), 'restore', {
        'component': component,
      }, actorKey: actorKey);
    }
    await txn.insert('sync_state', {
      'key': 'legacy_components_queued',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getPendingSyncOperations() async =>
      (await _database()).query(
        'sync_operations',
        where: _syncActorKey == null ? null : 'actor_key = ?',
        whereArgs: _syncActorKey == null ? null : [_syncActorKey],
        orderBy: 'queue_id ASC',
      );

  Future<void> updatePendingPayload(
    String operationId,
    Map<String, dynamic> payload,
  ) async {
    await (await _database()).update(
      'sync_operations',
      {'payload': jsonEncode(payload)},
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> removePendingOperation(String operationId) async {
    await (await _database()).delete(
      'sync_operations',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<int> getSyncCursor() async {
    final rows = await (await _database()).query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['server_cursor'],
      limit: 1,
    );
    return rows.isEmpty
        ? 0
        : int.tryParse(rows.first['value']?.toString() ?? '') ?? 0;
  }

  Future<void> applyServerChange(
    Map<String, dynamic> change, {
    String? preservedLocalImage,
  }) async {
    final db = await _database();
    final id = change['id']?.toString() ?? '';
    final revision = (change['revision'] as num?)?.toInt() ?? 0;
    if (id.isEmpty) return;
    await db.transaction((txn) async {
      final appliedVersion = await txn.query(
        'sync_versions',
        columns: ['revision'],
        where: 'component_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final knownRevision = appliedVersion.isEmpty
          ? -1
          : (appliedVersion.first['revision'] as num?)?.toInt() ?? -1;
      if (revision <= knownRevision) return;
      if (change['deleted'] == true) {
        if (change['purged'] == true) {
          final cached = await txn.query(
            'sync_state',
            columns: ['value'],
            where: 'key = ?',
            whereArgs: ['component_local_image_$id'],
            limit: 1,
          );
          var cachedPath = cached.isEmpty
              ? null
              : cached.first['value']?.toString();
          if (cachedPath == null) {
            final active = await txn.query(
              'components',
              columns: ['image'],
              where: 'id = ?',
              whereArgs: [id],
              limit: 1,
            );
            cachedPath = active.isEmpty
                ? null
                : active.first['image']?.toString();
          }
          if (cachedPath != null && await File(cachedPath).exists()) {
            await File(cachedPath).delete();
          }
          await txn.delete(
            'sync_state',
            where: 'key IN (?, ?)',
            whereArgs: [
              'component_local_image_$id',
              'component_remote_image_$id',
            ],
          );
          await txn.delete(
            'sync_operations',
            where: 'component_id = ?',
            whereArgs: [id],
          );
        }
        await txn.delete('components', where: 'id = ?', whereArgs: [id]);
        await txn.delete(
          'sync_operations',
          where: 'component_id = ?',
          whereArgs: [id],
        );
        await txn.insert('sync_tombstones', {
          'component_id': id,
          'revision': revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('sync_versions', {
          'component_id': id,
          'revision': revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return;
      }
      final tombstone = await txn.query(
        'sync_tombstones',
        columns: ['revision'],
        where: 'component_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (tombstone.isNotEmpty) {
        final deletedRevision =
            (tombstone.first['revision'] as num?)?.toInt() ?? 0;
        if (revision <= deletedRevision) return;
        await txn.delete(
          'sync_tombstones',
          where: 'component_id = ?',
          whereArgs: [id],
        );
      }

      final incoming = Map<String, dynamic>.from(
        change['component'] as Map? ?? const <String, dynamic>{},
      );
      incoming['id'] = id;
      final remoteImage = incoming['image']?.toString();
      if (remoteImage?.startsWith('storage://') == true) {
        final cachedRemoteImage = await txn.query(
          'sync_state',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['component_remote_image_$id'],
          limit: 1,
        );
        var localImage = preservedLocalImage;
        if (localImage == null &&
            cachedRemoteImage.isNotEmpty &&
            cachedRemoteImage.first['value'] == remoteImage) {
          final cachedLocalImage = await txn.query(
            'sync_state',
            columns: ['value'],
            where: 'key = ?',
            whereArgs: ['component_local_image_$id'],
            limit: 1,
          );
          if (cachedLocalImage.isNotEmpty) {
            localImage = cachedLocalImage.first['value']?.toString();
          }
        }
        if (localImage != null && await File(localImage).exists()) {
          incoming['image'] = localImage;
          await txn.insert('sync_state', {
            'key': 'component_local_image_$id',
            'value': localImage,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          incoming['image'] = remoteImage;
          await txn.delete(
            'sync_state',
            where: 'key = ?',
            whereArgs: ['component_local_image_$id'],
          );
        }
        await txn.insert('sync_state', {
          'key': 'component_remote_image_$id',
          'value': remoteImage!,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final operations = await txn.query(
        'sync_operations',
        columns: ['kind', 'payload'],
        where: 'component_id = ?',
        whereArgs: [id],
        orderBy: 'queue_id ASC',
      );
      for (final operation in operations) {
        if (operation['kind'] != 'patch') continue;
        try {
          final payload = jsonDecode(
            operation['payload']?.toString() ?? '{}',
          ) as Map<String, dynamic>;
          final changes = payload['changes'];
          if (changes is Map) {
            incoming.addAll(Map<String, dynamic>.from(changes));
          }
        } catch (_) {
          // Keep the server copy if a corrupt pending patch cannot be replayed.
        }
      }
      await txn.insert(
        'components',
        _componentRow(incoming),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('sync_versions', {
        'component_id': id,
        'revision': revision,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setSyncCursor(int cursor) async {
    await (await _database()).insert('sync_state', {
      'key': 'server_cursor',
      'value': cursor.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _enqueue(
    DatabaseExecutor txn,
    String componentId,
    String kind,
    Map<String, dynamic> payload, {
    String? actorKey,
  }) async {
    await txn.insert('sync_operations', {
      'operation_id': newOperationId(),
      'component_id': componentId,
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'actor_key': actorKey,
    });
  }

  static Map<String, Object?> _componentRow(Map<String, dynamic> data) => {
    'id': data['id']?.toString() ?? '',
    'namespace': _namespaceValue(data['namespace']),
    'category': data['category']?.toString() ?? 'Electrical',
    'subcategory': data['subcategory']?.toString() ?? '',
    'name': data['name']?.toString() ?? 'Unnamed',
    'qty': (data['qty'] as num?)?.toInt() ?? 1,
    'desc': data['desc']?.toString() ?? '',
    'pic': data['pic']?.toString() ?? '',
    'image': data['image']?.toString(),
    'location': data['location']?.toString() ?? '',
    'specs': data['specs']?.toString() ?? '',
    'status': data['status']?.toString() ?? 'available',
    'tags': jsonEncode(data['tags'] is List ? data['tags'] : const []),
    'created': data['created']?.toString() ?? '',
    'updated': data['updated']?.toString() ?? '',
  };

  static String _namespaceValue(Object? value) => value is ComponentNamespace
      ? value.keyName
      : value?.toString() ?? 'crate';

  static Component _toComponent(Map<String, Object?> row) {
    List<String> tags;
    try {
      final raw = row['tags'];
      final decoded = raw is String ? jsonDecode(raw) : raw;
      tags = decoded is List
          ? decoded.map((e) => e.toString()).toList()
          : const [];
    } catch (_) {
      tags = (row['tags']?.toString() ?? '')
          .split(',')
          .where((tag) => tag.trim().isNotEmpty)
          .map((tag) => tag.trim())
          .toList();
    }
    return Component(
      id: row['id']?.toString() ?? '',
      namespace: ComponentNamespace.fromString(row['namespace']?.toString()),
      category: row['category']?.toString() ?? '',
      subcategory: row['subcategory']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      qty: (row['qty'] as num?)?.toInt() ?? 0,
      desc: row['desc']?.toString() ?? '',
      pic: row['pic']?.toString() ?? '',
      image: row['image']?.toString(),
      location: row['location']?.toString() ?? '',
      specs: row['specs']?.toString() ?? '',
      status: ComponentStatusType.fromString(row['status']?.toString()),
      tags: tags,
      created: row['created']?.toString() ?? '',
      updated: row['updated']?.toString() ?? '',
    );
  }
}

List<Component> _decodeComponentRows(List<Map<String, Object?>> rows) =>
    rows.map(ComponentDao._toComponent).toList(growable: false);

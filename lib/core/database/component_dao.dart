import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/component.dart';
import '../../widgets/status_badge.dart';

class ComponentDao {
  final Future<Database> Function() _database;

  const ComponentDao(this._database);

  Future<void> seedIfEmpty() async {
    final db = await _database();
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM components'),
        ) ??
        0;
    if (count != 0) return;
    try {
      final source = await rootBundle.loadString('assets/data/armory.json');
      final data = jsonDecode(source) as Map<String, dynamic>;
      final rows = data['components'] as List<dynamic>? ?? const [];
      final batch = db.batch();
      for (final value in rows) {
        final item = value as Map<String, dynamic>;
        batch.insert(
          'components',
          _fromJson(item),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Keep the local repository usable when seed assets are unavailable.
    }
  }

  Future<List<Component>> getAll() async {
    await seedIfEmpty();
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
    await seedIfEmpty();
    final rows = await (await _database()).query(
      'components',
      orderBy: 'updated DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_toComponent).toList(growable: false);
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
        : 'COMP-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final now = DateTime.now().toIso8601String().split('T').first;
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
    await db.insert(
      'components',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return _toComponent(row);
  }

  Future<Component> update(String id, Map<String, dynamic> changes) async {
    final db = await _database();
    final exists = await getById(id);
    if (exists == null) throw StateError('Component [$id] not found');
    final values = <String, Object?>{
      'updated': DateTime.now().toIso8601String().split('T').first,
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
    await db.update('components', values, where: 'id = ?', whereArgs: [id]);
    return (await getById(id))!;
  }

  Future<bool> delete(String id) async =>
      await (await _database()).delete(
        'components',
        where: 'id = ?',
        whereArgs: [id],
      ) >
      0;

  static Map<String, Object?> _fromJson(Map<String, dynamic> item) => {
    'id': item['id']?.toString() ?? '',
    'namespace': _namespaceValue(item['namespace']),
    'category': item['category']?.toString() ?? '',
    'subcategory': item['subcategory']?.toString() ?? '',
    'name': item['name']?.toString() ?? '',
    'qty': (item['qty'] as num?)?.toInt() ?? 0,
    'desc': item['desc']?.toString() ?? '',
    'pic': item['pic']?.toString() ?? '',
    'image': item['image']?.toString(),
    'location': item['location']?.toString() ?? '',
    'specs': item['specs']?.toString() ?? '',
    'status': item['status']?.toString() ?? 'available',
    'tags': jsonEncode(item['tags'] ?? const []),
    'created': item['created']?.toString() ?? '',
    'updated': item['updated']?.toString() ?? '',
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

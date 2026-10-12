import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:armoury_flutter/core/database/component_dao.dart';
import 'package:armoury_flutter/core/repositories/i_component_repository.dart';
import 'package:armoury_flutter/models/component.dart';
import 'package:armoury_flutter/services/initial_data_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('armoury-seed-test');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test(
    'bundled rows and photos go through repository create exactly once',
    () async {
      final repo = _FakeComponentRepository();
      final dao = _FakeComponentDao();
      final service = InitialDataService(
        dao: dao,
        repository: repo,
        bundle: _MemoryBundle(_sampleInitialData()),
        documentsDirectory: () async => tempDirectory,
      );

      await service.seedIfNeeded();
      await service.seedIfNeeded();

      expect(repo.created, hasLength(1));
      expect(repo.created.single['id'], 'COMP-1234');
      expect(repo.created.single['created'], isNull);
      expect(repo.created.single['updated'], isNull);
      expect(repo.created.single['tags'], ['starter']);
      final imagePath = repo.created.single['image'] as String;
      expect(await File(imagePath).readAsBytes(), [0xFF, 0xD8, 0x01]);
      expect(dao.status, 'complete');
    },
  );

  test('does not seed over an existing local catalog', () async {
    final repo = _FakeComponentRepository();
    final dao = _FakeComponentDao()..seedable = false;
    final service = InitialDataService(
      dao: dao,
      repository: repo,
      bundle: _MemoryBundle(_sampleInitialData()),
      documentsDirectory: () async => tempDirectory,
    );

    await service.seedIfNeeded();

    expect(repo.created, isEmpty);
    expect(dao.status, 'complete');
  });
}

List<int> _sampleInitialData() {
  final archive = Archive();
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'ORCUS_ARMOURY',
      'components': [
        {
          'id': 'COMP-1234',
          'namespace': 'crate',
          'category': 'Electrical',
          'subcategory': 'Sensors',
          'name': 'Seeded sensor',
          'qty': 1,
          'desc': '',
          'pic': '',
          'image': '/old/device/component_images/sensor.jpg',
          'location': '',
          'specs': '',
          'status': 'available',
          'tags': '["starter"]',
          'created': '2026-10-01T00:00:00Z',
          'updated': '2026-10-02T00:00:00Z',
        },
      ],
    }),
  );
  archive.addFile(
    ArchiveFile('armoury_database.json', manifest.length, manifest),
  );
  const image = [0xFF, 0xD8, 0x01];
  archive.addFile(ArchiveFile('images/sensor.jpg', image.length, image));
  return ZipEncoder().encode(archive);
}

class _MemoryBundle extends CachingAssetBundle {
  final List<int> bytes;

  _MemoryBundle(this.bytes);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(bytes));
}

class _FakeComponentDao extends ComponentDao {
  _FakeComponentDao() : super(() async => throw UnimplementedError());

  bool seedable = true;
  String? status;

  @override
  Future<bool> canSeedBundledInitialData() async => seedable;

  @override
  Future<String?> getBundledInitialDataStatus() async => status;

  @override
  Future<bool> hasTombstone(String id) async => false;

  @override
  Future<void> setBundledInitialDataStatus(String value) async {
    status = value;
  }
}

class _FakeComponentRepository implements IComponentRepository {
  final created = <Map<String, dynamic>>[];
  final items = <String, Component>{};

  @override
  Future<Component> create(Map<String, dynamic> data) async {
    final copy = Map<String, dynamic>.from(data);
    created.add(copy);
    final component = Component.fromJson(copy);
    items[component.id] = component;
    return component;
  }

  @override
  Future<bool> delete(String id) async => items.remove(id) != null;

  @override
  Future<List<Component>> getAll() async => items.values.toList();

  @override
  Future<Component?> getById(String id) async => items[id];

  @override
  Future<List<Component>> getPage({
    required int offset,
    int limit = 50,
  }) async => items.values.skip(offset).take(limit).toList();

  @override
  Future<Component> update(String id, Map<String, dynamic> changes) async {
    final updated = items[id]!.copyWith(name: changes['name']?.toString());
    items[id] = updated;
    return updated;
  }
}

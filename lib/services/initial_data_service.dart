import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/database/component_dao.dart';
import '../core/repositories/i_component_repository.dart';

const bundledInitialDataAsset = 'assets/initial_data/current_components.zip';

class BundledInitialData {
  final List<Map<String, dynamic>> components;
  final Map<String, List<int>> imagesByName;

  const BundledInitialData({
    required this.components,
    required this.imagesByName,
  });
}

BundledInitialData decodeBundledInitialData(List<int> bytes) {
  final files = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? manifestFile;
  final images = <String, List<int>>{};
  for (final file in files) {
    if (!file.isFile) continue;
    if (file.name == 'armoury_database.json') {
      manifestFile = file;
    } else if (file.name.startsWith('images/')) {
      images[p.basename(file.name)] = List<int>.from(file.content as List<int>);
    }
  }
  if (manifestFile == null) {
    throw const FormatException(
      'Bundled initial data has no inventory manifest',
    );
  }
  final manifest = jsonDecode(
    utf8.decode(manifestFile.content as List<int>),
  ) as Map<String, dynamic>;
  if (manifest['app'] != 'ORCUS_ARMOURY' || manifest['components'] is! List) {
    throw const FormatException('Bundled initial data manifest is invalid');
  }
  final components = (manifest['components'] as List)
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
  for (final component in components) {
    final id = component['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Bundled component is missing its stable ID');
    }
    final reference = component['image']?.toString();
    if (reference == null || reference.isEmpty || reference == 'none') continue;
    final fileName = p.basename(reference.replaceAll('\\', '/'));
    if (!images.containsKey(fileName)) {
      throw FormatException('Bundled photo is missing: $fileName');
    }
  }
  return BundledInitialData(components: components, imagesByName: images);
}

/// Imports the bundled starter catalog through normal repository create calls.
/// Each create therefore gets the same local persistence and sync queue behavior
/// as a component entered through the app.
class InitialDataService {
  final ComponentDao _dao;
  final IComponentRepository _repository;
  final AssetBundle _bundle;
  final Future<Directory> Function() _documentsDirectory;

  InitialDataService({
    required this._dao,
    required this._repository,
    AssetBundle? bundle,
    Future<Directory> Function()? documentsDirectory,
  }) : _bundle = bundle ?? rootBundle,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<void> seedIfNeeded() async {
    final status = await _dao.getBundledInitialDataStatus();
    if (status == 'complete') return;
    final started = status == 'started';
    if (!started && !await _dao.canSeedBundledInitialData()) {
      await _dao.setBundledInitialDataStatus('complete');
      return;
    }

    final data = await _loadBundledData();
    final imagesDirectory = Directory(
      p.join((await _documentsDirectory()).path, 'component_images'),
    );
    await imagesDirectory.create(recursive: true);
    final imagePaths = <String, String>{};
    for (final component in data.components) {
      final reference = component['image']?.toString();
      if (reference == null || reference.isEmpty || reference == 'none') {
        continue;
      }
      final fileName = p.basename(reference.replaceAll('\\', '/'));
      final target = File(p.join(imagesDirectory.path, fileName));
      await target.writeAsBytes(data.imagesByName[fileName]!, flush: true);
      imagePaths[reference] = target.path;
    }

    if (!started) await _dao.setBundledInitialDataStatus('started');
    for (final bundled in data.components) {
      final component = Map<String, dynamic>.from(bundled);
      final id = component['id'].toString();
      if (await _repository.getById(id) != null ||
          await _dao.hasTombstone(id)) {
        continue;
      }
      final image = component['image']?.toString();
      component['image'] = image == null ? null : imagePaths[image];
      component.remove('created');
      component.remove('updated');
      final tags = component['tags'];
      if (tags is String) {
        try {
          final decoded = jsonDecode(tags);
          component['tags'] = decoded is List ? decoded : const <String>[];
        } catch (_) {
          component['tags'] = const <String>[];
        }
      }
      await _repository.create(component);
    }
    await _dao.setBundledInitialDataStatus('complete');
  }

  Future<BundledInitialData> _loadBundledData() async {
    final bytes = await _bundle.load(bundledInitialDataAsset);
    return decodeBundledInitialData(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_models.dart';

String inventoryRowsAsCsv(List<Map<String, Object?>> rows) {
  const columns = [
    'name',
    'namespace',
    'category',
    'subcategory',
    'qty',
    'desc',
    'location',
    'specs',
    'status',
    'tags',
    'created',
    'updated',
  ];
  String cell(Object? value) {
    final text = value is List ? value.join('; ') : (value?.toString() ?? '');
    return '"${text.replaceAll('"', '""')}"';
  }

  final output = StringBuffer()..writeln(columns.map(cell).join(','));
  for (final row in rows) {
    output.writeln(
      columns
          .map((key) {
            var value = row[key];
            if (key == 'tags' && value is String) {
              try {
                value = jsonDecode(value) as List;
              } catch (_) {}
            }
            return cell(value);
          })
          .join(','),
    );
  }
  return output.toString();
}

/// Builds a portable, download-only inventory package with a CSV and its photos.
/// Internal component IDs are used only to associate rows with files and are not exported.
List<int> inventoryPackageZipBytes(
  List<Map<String, Object?>> rows,
  Map<String, InventoryImageFile> imagesByComponentId,
) {
  final csvColumns = [
    'name',
    'namespace',
    'category',
    'subcategory',
    'qty',
    'desc',
    'location',
    'specs',
    'status',
    'tags',
    'created',
    'updated',
    'image_file',
  ];
  String cell(Object? value) {
    final text = value is List ? value.join('; ') : (value?.toString() ?? '');
    return '"${text.replaceAll('"', '""')}"';
  }

  var imageIndex = 0;
  final imagePaths = <String, String>{};
  final archive = Archive();
  for (final row in rows) {
    final id = row['id']?.toString();
    if (id == null) continue;
    final image = imagesByComponentId[id];
    if (image == null) continue;
    imageIndex++;
    final extension = image.extension
        .replaceFirst(RegExp(r'^\.'), '')
        .toLowerCase();
    final fileName =
        'images/photo_${imageIndex.toString().padLeft(4, '0')}.$extension';
    imagePaths[id] = fileName;
    archive.addFile(ArchiveFile(fileName, image.bytes.length, image.bytes));
  }

  final csv = StringBuffer()..writeln(csvColumns.map(cell).join(','));
  for (final row in rows) {
    final id = row['id']?.toString();
    final values = <Object?>[
      row['name'],
      row['namespace'],
      row['category'],
      row['subcategory'],
      row['qty'],
      row['desc'],
      row['location'],
      row['specs'],
      row['status'],
      row['tags'],
      row['created'],
      row['updated'],
      id == null ? null : imagePaths[id],
    ];
    final tagsIndex = 9;
    if (values[tagsIndex] is String) {
      try {
        values[tagsIndex] = jsonDecode(values[tagsIndex]! as String) as List;
      } catch (_) {}
    }
    csv.writeln(values.map(cell).join(','));
  }
  final csvBytes = Uint8List.fromList([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(csv.toString()),
  ]);
  archive.addFile(ArchiveFile('inventory.csv', csvBytes.length, csvBytes));
  return ZipEncoder().encode(archive);
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:armoury_flutter/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Standard ZIP archive creation and extraction integrity', () {
    final manifest = {
      'app': 'ORCUS_ARMOURY',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'componentCount': 2,
      'components': [
        {'id': 'ARM-001', 'name': 'Raspberry Pi 4', 'qty': 2},
        {'id': 'ARM-002', 'name': 'Soldering Station', 'qty': 1},
      ],
      'app_content': [],
    };

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('armoury_database.json', jsonBytes.length, jsonBytes),
    );

    final sampleImage = utf8.encode('fake-jpg-binary-data');
    archive.addFile(
      ArchiveFile('images/test_img.jpg', sampleImage.length, sampleImage),
    );

    // Encode to ZIP bytes
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    expect(zipBytes.isNotEmpty, true);

    // Decode from ZIP bytes
    final zipDecoder = ZipDecoder();
    final decodedArchive = zipDecoder.decodeBytes(zipBytes);

    expect(decodedArchive.length, 2);

    final extractedJsonFile = decodedArchive.firstWhere(
      (f) => f.name == 'armoury_database.json',
    );
    final extractedData = jsonDecode(
      utf8.decode(extractedJsonFile.content as List<int>),
    ) as Map<String, dynamic>;

    expect(extractedData['app'], 'ORCUS_ARMOURY');
    expect((extractedData['components'] as List).length, 2);

    final extractedImg = decodedArchive.firstWhere(
      (f) => f.name == 'images/test_img.jpg',
    );
    expect(
      utf8.decode(extractedImg.content as List<int>),
      'fake-jpg-binary-data',
    );
  });

  test('BackupExportResult and BackupImportResult model integrity', () {
    const successResult = BackupExportResult(
      success: true,
      savedPath: '/storage/emulated/0/Download/backup.zip',
      fileSize: 1048576 * 2, // 2MB
      componentCount: 15,
    );

    expect(successResult.success, true);
    expect(successResult.cancelled, false);
    expect(successResult.sizeFormatted, '2.0 MB');
    expect(successResult.componentCount, 15);

    final cancelledExport = BackupExportResult.cancelled();
    expect(cancelledExport.success, false);
    expect(cancelledExport.cancelled, true);

    final failedExport = BackupExportResult.failure('Permission Denied');
    expect(failedExport.success, false);
    expect(failedExport.error, 'Permission Denied');

    const successImport = BackupImportResult(
      success: true,
      restoredCount: 12,
      fileName: 'armoury_backup.zip',
    );
    expect(successImport.success, true);
    expect(successImport.restoredCount, 12);
    expect(successImport.fileName, 'armoury_backup.zip');

    final cancelledImport = BackupImportResult.cancelled();
    expect(cancelledImport.success, false);
    expect(cancelledImport.cancelled, true);

    final failedImport = BackupImportResult.failure('Corrupt ZIP');
    expect(failedImport.success, false);
    expect(failedImport.error, 'Corrupt ZIP');
  });

  test('inventory CSV exports dates and quotes data without exposing IDs', () {
    final csv = inventoryRowsAsCsv([
      {
        'id': 'internal-id',
        'name': 'Motor, "A"',
        'namespace': 'crate',
        'qty': 2,
        'tags': '["spare", "drive"]',
        'created': '2026-10-09T08:00:00Z',
        'updated': '2026-10-09T09:15:00Z',
      },
    ]);
    expect(csv, contains('"name"'));
    expect(csv, contains('"created"'));
    expect(csv, contains('"updated"'));
    expect(csv, contains('"Motor, ""A"""'));
    expect(csv, contains('"spare; drive"'));
    expect(csv, isNot(contains('internal-id')));
    expect(csv, contains('2026-10-09T09:15:00Z'));
  });

  test('download package contains CSV photo references and image bytes', () {
    final bytes = inventoryPackageZipBytes(
      [
        {
          'id': 'private-component-id',
          'name': 'Motor controller',
          'namespace': 'crate',
          'qty': 1,
          'created': '2026-10-09T08:00:00Z',
          'updated': '2026-10-09T09:15:00Z',
        },
      ],
      {
        'private-component-id': InventoryImageFile(
          extension: 'jpg',
          bytes: Uint8List.fromList([0xFF, 0xD8, 0x01]),
        ),
      },
    );

    final files = ZipDecoder().decodeBytes(bytes);
    expect(
      files.map((file) => file.name),
      containsAll(['inventory.csv', 'images/photo_0001.jpg']),
    );
    final csv = utf8.decode(
      files.firstWhere((file) => file.name == 'inventory.csv').content
          as List<int>,
    );
    expect(csv, contains('"image_file"'));
    expect(csv, contains('"images/photo_0001.jpg"'));
    expect(csv, isNot(contains('private-component-id')));
    expect(
      files.firstWhere((file) => file.name == 'images/photo_0001.jpg').content,
      [0xFF, 0xD8, 0x01],
    );
  });
}

import 'dart:convert';
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
    archive.addFile(ArchiveFile('armoury_database.json', jsonBytes.length, jsonBytes));

    final sampleImage = utf8.encode('fake-jpg-binary-data');
    archive.addFile(ArchiveFile('images/test_img.jpg', sampleImage.length, sampleImage));

    // Encode to ZIP bytes
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    expect(zipBytes.isNotEmpty, true);

    // Decode from ZIP bytes
    final zipDecoder = ZipDecoder();
    final decodedArchive = zipDecoder.decodeBytes(zipBytes);

    expect(decodedArchive.length, 2);

    final extractedJsonFile = decodedArchive.firstWhere((f) => f.name == 'armoury_database.json');
    final extractedData = jsonDecode(utf8.decode(extractedJsonFile.content as List<int>)) as Map<String, dynamic>;

    expect(extractedData['app'], 'ORCUS_ARMOURY');
    expect((extractedData['components'] as List).length, 2);

    final extractedImg = decodedArchive.firstWhere((f) => f.name == 'images/test_img.jpg');
    expect(utf8.decode(extractedImg.content as List<int>), 'fake-jpg-binary-data');
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
}

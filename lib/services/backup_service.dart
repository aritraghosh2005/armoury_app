import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_provider.dart';

class DetectedBackup {
  final File file;
  final String fileName;
  final int sizeBytes;
  final DateTime modified;

  const DetectedBackup({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.modified,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupExportResult {
  final bool success;
  final bool cancelled;
  final String? savedPath;
  final int fileSize;
  final int componentCount;
  final String? error;

  const BackupExportResult({
    required this.success,
    this.cancelled = false,
    this.savedPath,
    this.fileSize = 0,
    this.componentCount = 0,
    this.error,
  });

  String get sizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory BackupExportResult.cancelled() => const BackupExportResult(
        success: false,
        cancelled: true,
      );

  factory BackupExportResult.failure(String error) => BackupExportResult(
        success: false,
        error: error,
      );
}

class BackupImportResult {
  final bool success;
  final bool cancelled;
  final int restoredCount;
  final String? fileName;
  final String? error;

  const BackupImportResult({
    required this.success,
    this.cancelled = false,
    this.restoredCount = 0,
    this.fileName,
    this.error,
  });

  factory BackupImportResult.cancelled() => const BackupImportResult(
        success: false,
        cancelled: true,
      );

  factory BackupImportResult.failure(String error) => BackupImportResult(
        success: false,
        error: error,
      );
}

class BackupService {
  final DatabaseProvider _databaseProvider;

  BackupService(this._databaseProvider);

  /// Scans common storage directories (Downloads, Documents, App Storage)
  /// for any existing `.zip` backup files.
  Future<List<DetectedBackup>> findStorageBackups() async {
    final List<DetectedBackup> results = [];
    final Set<String> scannedPaths = {};

    final candidateDirs = <Directory>[];

    try {
      // 1. App documents directory
      candidateDirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {}

    try {
      // 2. Downloads directory
      final downloads = await getDownloadsDirectory();
      if (downloads != null) candidateDirs.add(downloads);
    } catch (_) {}

    try {
      // 3. External storage directory
      final ext = await getExternalStorageDirectory();
      if (ext != null) candidateDirs.add(ext);
    } catch (_) {}

    // 4. Android primary public storage directories
    if (!kIsWeb && Platform.isAndroid) {
      candidateDirs.add(Directory('/storage/emulated/0/Download'));
      candidateDirs.add(Directory('/storage/emulated/0/Documents'));
      candidateDirs.add(Directory('/sdcard/Download'));
    }

    for (final dir in candidateDirs) {
      if (!dir.existsSync()) continue;
      try {
        final list = dir.listSync(recursive: false);
        for (final entity in list) {
          if (entity is File) {
            final name = p.basename(entity.path).toLowerCase();
            if ((name.endsWith('.zip') || name.endsWith('.orcus')) &&
                !scannedPaths.contains(entity.path)) {
              scannedPaths.add(entity.path);
              try {
                final stat = entity.statSync();
                results.add(
                  DetectedBackup(
                    file: entity,
                    fileName: p.basename(entity.path),
                    sizeBytes: stat.size,
                    modified: stat.modified,
                  ),
                );
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('[BackupService] Scan error in ${dir.path}: $e');
      }
    }

    // Sort newest first
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// Exports the entire repository (SQLite DB records + local images)
  /// into a standard `.zip` archive file, opening the native folder tree / save dialog
  /// so the user can navigate and save at their convenient location.
  Future<BackupExportResult> exportBackupWithPicker() async {
    try {
      final db = await _databaseProvider.database;

      // 1. Fetch all components
      final components = await db.query('components');

      // 2. Fetch all app_content
      final appContent = await db.query('app_content');

      final manifest = {
        'app': 'ORCUS_ARMOURY',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'componentCount': components.length,
        'components': components,
        'app_content': appContent,
      };

      final archive = Archive();

      // 3. Add manifest database JSON to ZIP
      final jsonBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(
        ArchiveFile('armoury_database.json', jsonBytes.length, jsonBytes),
      );

      // 4. Collect and add all local hardware photo assets to ZIP
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'component_images'));

      if (await imagesDir.exists()) {
        final files = imagesDir.listSync(recursive: false);
        for (final entity in files) {
          if (entity is File) {
            try {
              final fileName = p.basename(entity.path);
              final imgBytes = await entity.readAsBytes();
              archive.addFile(
                ArchiveFile('images/$fileName', imgBytes.length, imgBytes),
              );
            } catch (e) {
              debugPrint('[BackupService] Could not read image ${entity.path}: $e');
            }
          }
        }
      }

      // 5. Encode archive to standard ZIP format
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      final zipBytes = Uint8List.fromList(zipData);

      // 6. Generate formatted default file name
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final defaultFileName = 'armoury_backup_$dateStr.zip';

      // 7. Let user navigate folder tree to save the file
      Uri? savedUri;

      try {
        savedUri = await FilePicker.saveFile(
          dialogTitle: 'Select location to save backup archive (.zip)',
          fileName: defaultFileName,
          bytes: zipBytes,
          type: FileType.custom,
          allowedExtensions: ['zip'],
          mimeType: 'application/zip',
        );
      } catch (e) {
        debugPrint('[BackupService] FilePicker.saveFile threw: $e');
      }

      // Fallback to directory picker if saveFile failed or was not supported
      if (savedUri == null) {
        try {
          final dirPath = await FilePicker.getDirectoryPath(
            dialogTitle: 'Select destination folder for backup (.zip)',
          );
          if (dirPath != null) {
            final targetPath = p.join(dirPath, defaultFileName);
            final targetFile = File(targetPath);
            await targetFile.writeAsBytes(zipBytes);
            savedUri = Uri.file(targetPath);
          }
        } catch (e) {
          debugPrint('[BackupService] FilePicker.getDirectoryPath threw: $e');
        }
      }

      if (savedUri == null) {
        return BackupExportResult.cancelled();
      }

      String displayPath;
      if (savedUri.isScheme('file')) {
        try {
          displayPath = savedUri.toFilePath();
        } catch (_) {
          displayPath = savedUri.path;
        }
      } else {
        displayPath = savedUri.path.isNotEmpty ? savedUri.path : defaultFileName;
      }

      return BackupExportResult(
        success: true,
        savedPath: displayPath,
        fileSize: zipBytes.length,
        componentCount: components.length,
      );
    } catch (e, stack) {
      debugPrint('[BackupService] Export failed: $e\n$stack');
      return BackupExportResult.failure(e.toString());
    }
  }

  /// Opens the native folder tree / file browser so the user can navigate
  /// to their intended `.zip` backup file and restore the repository.
  Future<BackupImportResult> importBackupWithPicker({bool overwrite = true}) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip', 'orcus'],
        dialogTitle: 'Select Armoury Backup Archive (.zip)',
      );

      if (picked == null) {
        return BackupImportResult.cancelled();
      }

      final fileName = picked.name;
      final bytes = await picked.xFile.readAsBytes();

      if (bytes.isEmpty) {
        return BackupImportResult.failure('Selected backup file is empty or unreadable.');
      }

      final restoredCount = await restoreBackupFromBytes(bytes, overwrite: overwrite);

      return BackupImportResult(
        success: true,
        restoredCount: restoredCount,
        fileName: fileName,
      );
    } catch (e, stack) {
      debugPrint('[BackupService] Import failed: $e\n$stack');
      return BackupImportResult.failure(e.toString());
    }
  }

  /// Restores components and image assets from a byte buffer of a `.zip` archive
  Future<int> restoreBackupFromBytes(List<int> bytes, {bool overwrite = true}) async {
    final zipDecoder = ZipDecoder();
    final archive = zipDecoder.decodeBytes(bytes);

    ArchiveFile? manifestFile;
    final List<ArchiveFile> imageFiles = [];

    for (final file in archive) {
      if (!file.isFile) continue;
      final lowerName = file.name.toLowerCase();
      if (file.name == 'armoury_database.json' || lowerName.endsWith('.json')) {
        manifestFile = file;
      } else if (file.name.startsWith('images/') ||
          lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png') ||
          lowerName.endsWith('.webp')) {
        imageFiles.add(file);
      }
    }

    if (manifestFile == null) {
      throw const FormatException('Invalid backup archive: missing database manifest in zip.');
    }

    // 1. Unpack images into component_images directory
    final appDir = await getApplicationDocumentsDirectory();
    final targetImagesDir = Directory(p.join(appDir.path, 'component_images'));
    if (!await targetImagesDir.exists()) {
      await targetImagesDir.create(recursive: true);
    }

    for (final img in imageFiles) {
      try {
        final cleanName = p.basename(img.name);
        final content = img.content as List<int>;
        final targetImgFile = File(p.join(targetImagesDir.path, cleanName));
        await targetImgFile.writeAsBytes(content);
      } catch (e) {
        debugPrint('[BackupService] Failed writing image ${img.name}: $e');
      }
    }

    // 2. Parse database manifest
    final manifestBytes = manifestFile.content as List<int>;
    final jsonStr = utf8.decode(manifestBytes);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final components = (data['components'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final appContent = (data['app_content'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final db = await _databaseProvider.database;
    var restoredCount = 0;

    await db.transaction((txn) async {
      if (overwrite) {
        await txn.delete('components');
        await txn.delete('app_content');
      }

      for (final row in components) {
        await txn.insert(
          'components',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        restoredCount++;
      }

      for (final row in appContent) {
        await txn.insert(
          'app_content',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return restoredCount;
  }

  /// Restores components and image assets from a standard `.zip` backup file
  Future<int> restoreBackupFromZip(File zipFile, {bool overwrite = false}) async {
    final bytes = await zipFile.readAsBytes();
    return restoreBackupFromBytes(bytes, overwrite: overwrite);
  }
}

import 'dart:io';
import 'dart:typed_data';

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
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupExportResult {
  final bool success;
  final bool cancelled;
  final String? savedPath;
  final int fileSize;
  final int componentCount;
  final int imageCount;
  final String? error;

  const BackupExportResult({
    required this.success,
    this.cancelled = false,
    this.savedPath,
    this.fileSize = 0,
    this.componentCount = 0,
    this.imageCount = 0,
    this.error,
  });

  String get sizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory BackupExportResult.cancelled() =>
      const BackupExportResult(success: false, cancelled: true);

  factory BackupExportResult.failure(String error) =>
      BackupExportResult(success: false, error: error);
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

  factory BackupImportResult.cancelled() =>
      const BackupImportResult(success: false, cancelled: true);

  factory BackupImportResult.failure(String error) =>
      BackupImportResult(success: false, error: error);
}

class InventoryImageFile {
  final String extension;
  final Uint8List bytes;

  const InventoryImageFile({required this.extension, required this.bytes});
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backup_service.dart';
import 'viewmodels/armoury_viewmodel.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final dbProvider = ref.watch(databaseProvider);
  return BackupService(dbProvider);
});

final detectedBackupsProvider = FutureProvider<List<DetectedBackup>>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return service.findStorageBackups();
});

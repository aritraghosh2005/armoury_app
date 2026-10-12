import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_service.dart';
import 'app_providers.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final dbProvider = ref.watch(databaseProvider);
  return BackupService(dbProvider, backendApi: ref.watch(backendApiProvider));
});

final detectedBackupsProvider = FutureProvider<List<DetectedBackup>>((
  ref,
) async {
  final service = ref.watch(backupServiceProvider);
  return service.findStorageBackups();
});

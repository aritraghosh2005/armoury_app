import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/component_dao.dart';
import '../core/database/content_dao.dart';
import '../core/database/database_provider.dart';
import '../core/repositories/component_repository.dart';
import '../core/repositories/i_component_repository.dart';
import '../core/sync/backend_api.dart';
import '../core/sync/sync_coordinator.dart';
import '../services/initial_data_service.dart';
import '../services/supabase_auth_service.dart';

final databaseProvider = Provider<DatabaseProvider>(
  (ref) => DatabaseProvider(),
);

final componentDaoProvider = Provider<ComponentDao>(
  (ref) => ComponentDao(() => ref.watch(databaseProvider).database),
);

final contentDaoProvider = Provider<ContentDao>(
  (ref) => ContentDao(() => ref.watch(databaseProvider).database),
);

final componentRepositoryProvider = Provider<IComponentRepository>(
  (ref) => ComponentRepository(ref.watch(componentDaoProvider)),
);

final initialDataServiceProvider = Provider<InitialDataService>((ref) {
  return InitialDataService(
    dao: ref.watch(componentDaoProvider),
    repository: ref.watch(componentRepositoryProvider),
  );
});

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    ref.watch(componentDaoProvider),
    ref.watch(backendApiProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>(
  (ref) => SupabaseAuthService(
    ref.watch(componentDaoProvider),
    ref.watch(backendApiProvider),
  ),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';

final adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(backendApiProvider).getAdminUsers(),
);
final adminAuditProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(backendApiProvider).getAdminAudit(limit: 50),
);

final adminViewModelProvider = Provider<AdminViewModel>(
  (ref) => AdminViewModel(ref),
);

class AdminViewModel {
  final Ref _ref;
  AdminViewModel(this._ref);

  Future<void> setAccess(
    Map<String, dynamic> user,
    String status,
    String role,
  ) async {
    await _ref
        .read(backendApiProvider)
        .updateUserAccess(
          user['userId'].toString(),
          status: status,
          role: role,
        );
    _ref.invalidate(adminUsersProvider);
    _ref.invalidate(adminAuditProvider);
  }
}

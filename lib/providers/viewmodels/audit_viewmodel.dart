import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';

final auditEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(backendApiProvider).getAudit(limit: 20);
});

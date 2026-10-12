import 'dart:io';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase RPC and Storage boundary for the app. ViewModels and widgets do not
/// know the PostgREST schema or storage bucket layout.
class BackendApi {
  static const configuredBaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const configuredPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  final SupabaseClient? _client;
  final Dio _http = Dio();
  final String baseUrl;
  String? _deviceId;
  bool _writeEnabled = false;
  void Function(String code)? onAccessDenied;

  BackendApi({SupabaseClient? client, String? baseUrl})
    : _client = client ?? _initializedClientOrNull(),
      baseUrl = (baseUrl ?? configuredBaseUrl).trim().replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  static SupabaseClient? _initializedClientOrNull() {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    }
  }

  bool get isConfigured => _client != null && baseUrl.isNotEmpty;
  String get syncNamespace => Uri.tryParse(baseUrl)?.host ?? baseUrl;
  bool get isAuthenticated =>
      _client?.auth.currentSession != null && _deviceId != null;
  bool get canWrite => _writeEnabled;
  SupabaseClient? get client => _client;
  Map<String, String> get authHeaders {
    final session = _client?.auth.currentSession;
    if (session == null) return const {};
    return {
      'apikey': configuredPublishableKey,
      'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null || baseUrl.isEmpty) {
      throw StateError(
        'Supabase is not configured for this build. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }
    return client;
  }

  String? get deviceId => _deviceId;

  void setIdentity(String deviceId, {bool canWrite = false}) {
    _deviceId = deviceId;
    _writeEnabled = canWrite;
  }

  void clearIdentity() {
    _deviceId = null;
    _writeEnabled = false;
  }

  Future<Map<String, dynamic>> registerDevice(
    String _,
    String deviceId,
    String deviceName,
    String platform,
  ) async {
    _deviceId = deviceId;
    final result = await _rpc('armoury_register_device', {
      'p_device_id': deviceId,
      'p_device_name': deviceName,
      'p_platform': platform,
    });
    return _asMap(result);
  }

  Future<Map<String, dynamic>> createComponent(
    String id,
    Map<String, dynamic> component,
    String operationId,
  ) => _applyOperation(id, operationId, 'create', component: component);

  Future<Map<String, dynamic>> patchComponent(
    String id,
    Map<String, dynamic> changes,
    String operationId,
  ) => _applyOperation(id, operationId, 'patch', changes: changes);

  Future<Map<String, dynamic>> restoreComponent(
    String id,
    Map<String, dynamic> component,
    String operationId,
  ) => _applyOperation(id, operationId, 'restore', component: component);

  Future<Map<String, dynamic>> deleteComponent(String id, String operationId) =>
      _applyOperation(id, operationId, 'delete');

  Future<Map<String, dynamic>> _applyOperation(
    String id,
    String operationId,
    String kind, {
    Map<String, dynamic>? component,
    Map<String, dynamic>? changes,
  }) async => _asMap(
    await _rpc('armoury_apply_operation', {
      'p_device_id': _requireDevice(),
      'p_operation_id': operationId,
      'p_component_id': id,
      'p_kind': kind,
      'p_component': component,
      'p_changes': changes,
    }),
  );

  Future<Map<String, dynamic>> changesSince(int cursor) async => _asMap(
    await _rpc('armoury_changes_since', {
      'p_device_id': _requireDevice(),
      'p_since': cursor,
      'p_limit': 200,
    }),
  );

  Future<List<Map<String, dynamic>>> getArchive() async => _items(
    await _rpc('armoury_list_archive', {'p_device_id': _requireDevice()}),
  );

  Future<List<Map<String, dynamic>>> getAudit({int limit = 100}) async =>
      _items(
        await _rpc('armoury_audit', {
          'p_device_id': _requireDevice(),
          'p_limit': limit,
        }),
      );

  Future<List<Map<String, dynamic>>> getAdminUsers() async => _items(
    await _rpc('armoury_admin_list_users', {'p_device_id': _requireDevice()}),
  );

  Future<List<Map<String, dynamic>>> getAdminAudit({int limit = 100}) async =>
      _items(
        await _rpc('armoury_admin_audit', {
          'p_device_id': _requireDevice(),
          'p_limit': limit,
        }),
      );

  Future<void> updateUserAccess(
    String userId, {
    required String status,
    required String role,
  }) async {
    await _rpc('armoury_admin_set_user', {
      'p_device_id': _requireDevice(),
      'p_target_id': userId,
      'p_status': status,
      'p_role': role,
    });
  }

  Future<Map<String, dynamic>> restoreArchived(
    String id,
    String operationId,
  ) async => _asMap(
    await _rpc('armoury_restore_archived', {
      'p_device_id': _requireDevice(),
      'p_component_id': id,
      'p_operation_id': operationId,
    }),
  );

  Future<void> permanentlyDeleteArchived(String id) async {
    await _rpc('armoury_purge_archived', {
      'p_device_id': _requireDevice(),
      'p_component_id': id,
    });
  }

  /// Uploads through the device-authorized media function and returns a
  /// non-public stable Storage reference.
  Future<String> uploadImage(
    String path, {
    String? componentId,
    String? operationId,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Image not found', path);
    }
    final extension = _imageExtension(path);
    final owner = _safePathSegment(componentId ?? 'unassigned');
    final stableOperationId = _safePathSegment(
      operationId ?? DateTime.now().microsecondsSinceEpoch.toString(),
    );
    final objectPath = '$owner/$stableOperationId.$extension';
    await _http.put<void>(
      _mediaUrl(objectPath),
      data: await file.readAsBytes(),
      options: Options(
        headers: {
          ...headersForImage(objectPath),
          'Content-Type': _contentType(extension),
        },
        responseType: ResponseType.json,
      ),
    );
    return 'storage://component-images/$objectPath';
  }

  Future<List<int>> downloadImage(Uri uri) async {
    if (uri.scheme == 'storage') {
      final path = uri.path.replaceFirst(RegExp(r'^/+'), '');
      final response = await _http.get<List<int>>(
        _mediaUrl(path),
        options: Options(
          headers: headersForImage(path),
          responseType: ResponseType.bytes,
        ),
      );
      return response.data ?? const <int>[];
    }
    throw ArgumentError.value(uri, 'uri', 'Unsupported remote image reference');
  }

  Future<String> getImageUrl(String image) async {
    final uri = Uri.tryParse(image);
    if (uri?.scheme == 'storage') {
      final path = uri!.path.replaceFirst(RegExp(r'^/+'), '');
      return _mediaUrl(path);
    }
    return image;
  }

  Future<String?> prepareImage(
    String? image, {
    String? componentId,
    String? operationId,
  }) async {
    final value = image?.trim();
    if (value == null || value.isEmpty || value == 'none') return value;
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'storage' || uri?.hasScheme == true) return value;
    final file = File(value);
    if (!await file.exists()) return 'none';
    return uploadImage(
      value,
      componentId: componentId,
      operationId: operationId,
    );
  }

  String resolveImage(String? image) => image ?? 'none';

  Map<String, String> headersForImage(String _) {
    final deviceId = _deviceId;
    final deviceHeader = deviceId == null ? null : 'x-armoury-device-id';
    return {
      ...authHeaders,
      ?deviceHeader: deviceId ?? '',
    };
  }

  String _mediaUrl(String path) {
    if (!isConfigured) {
      throw StateError('Supabase is not configured for this build.');
    }
    return '$baseUrl/functions/v1/armoury-media?path=${Uri.encodeQueryComponent(path)}';
  }

  Future<dynamic> _rpc(String function, Map<String, dynamic> parameters) async {
    final client = _requiredClient;
    try {
      final result = await client.rpc(function, params: parameters);
      return result;
    } on PostgrestException catch (error) {
      final code = error.code ?? 'remote_error';
      final status = switch (code) {
        '42501' => 403,
        'P0002' => 410,
        _ => 400,
      };
      if (status == 403) {
        final accessCode = _accessCode(error.message);
        if (accessCode == 'read_only') _writeEnabled = false;
        onAccessDenied?.call(accessCode);
      }
      throw ArmouryRemoteException(code, error.message, status);
    }
  }

  String _accessCode(String message) {
    for (final code in [
      'account_pending',
      'account_disabled',
      'device_not_registered',
      'read_only',
      'admin_required',
    ]) {
      if (message.contains(code)) return code;
    }
    return 'access_denied';
  }

  String _requireDevice() =>
      _deviceId ?? (throw StateError('This device is not registered'));

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<Map<String, dynamic>> _items(dynamic value) {
    final items = _asMap(value)['items'];
    return (items is List ? items : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static String _safePathSegment(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static String _imageExtension(String path) {
    final extension = path.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? (extension == 'jpeg' ? 'jpg' : extension)
        : 'jpg';
  }

  static String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

class ArmouryRemoteException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ArmouryRemoteException(this.code, this.message, this.statusCode);

  @override
  String toString() => message;
}

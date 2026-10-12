import 'package:flutter/foundation.dart';
import 'package:gotrue/gotrue.dart' show OtpType, UserAttributes;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../core/database/component_dao.dart';
import '../core/sync/backend_api.dart';

class ArmouryAccount {
  final String email;
  final String accountKey;
  final String status;
  final String role;
  final bool offline;

  const ArmouryAccount({
    required this.email,
    required this.accountKey,
    required this.status,
    required this.role,
    this.offline = false,
  });

  bool get canAccessInventory => status == 'active';
  bool get canEdit =>
      canAccessInventory && (role == 'editor' || role == 'admin');
  bool get isAdmin => canAccessInventory && role == 'admin';
}

/// Uses Supabase Auth email/password accounts, then registers each installation
/// with the authenticated RPC boundary before allowing shared data access.
class SupabaseAuthService {
  final ComponentDao _dao;
  final BackendApi _api;

  SupabaseAuthService(this._dao, this._api);

  bool get isConfigured => _api.isConfigured;

  Future<ArmouryAccount?> restoreSession() async {
    final user = _api.client?.auth.currentUser;
    if (user == null) return null;
    return _registerExisting(email: user.email ?? '', accountKey: user.id);
  }

  /// Returns null when Supabase requires the user to confirm their email
  /// before creating a session. No inventory device is registered until then.
  Future<ArmouryAccount?> signUp(String email, String password) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    final session = response.session;
    if (user == null) {
      throw StateError(
        'Supabase did not create the account. Please try again.',
      );
    }
    if (session == null) return null;
    return _registerExisting(email: user.email ?? email, accountKey: user.id);
  }

  Future<ArmouryAccount> signIn(String email, String password) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) throw StateError('Supabase did not create a session.');
    return _registerExisting(email: user.email ?? email, accountKey: user.id);
  }

  Future<ArmouryAccount> verifySignUpEmail(String email, String token) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }
    final response = await client.auth.verifyOTP(
      // signUp() and resend(type: signup) issue signup confirmation tokens.
      // The `email` OTP type is a different email sign-in flow in GoTrue.
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
    final user = response.user;
    if (user == null || response.session == null) {
      throw StateError('Email verification did not create a session.');
    }
    return _registerExisting(email: user.email ?? email, accountKey: user.id);
  }

  Future<void> resendSignUpCode(String email) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }
    await client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> requestPasswordReset(String email) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> completePasswordReset({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final client = _api.client;
    if (client == null || !_api.isConfigured) {
      throw StateError('Supabase Auth is not configured for this build.');
    }

    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: token.trim(),
      );
      if (response.user == null || response.session == null) {
        throw StateError('The reset code is invalid or has expired.');
      }
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (_) {
      // Recovery verification creates an authenticated session. Never leave
      // that session behind if updating the password fails partway through.
      await _clearRecoverySession(client);
      rethrow;
    }

    await _clearRecoverySession(client);
  }

  Future<void> _clearRecoverySession(SupabaseClient client) async {
    _api.clearIdentity();
    _dao.setSyncActor(null);
    try {
      await client.auth.signOut();
    } catch (_) {
      // The password change is authoritative; local identity is already clear.
    }
  }

  Future<ArmouryAccount> _registerExisting({
    required String email,
    required String accountKey,
  }) async {
    final deviceId = await _dao.getOrCreateDeviceId(accountKey: accountKey);
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final deviceName = kIsWeb ? 'Armoury Web' : 'Armoury $platform device';
    _api.setIdentity(deviceId);
    _dao.setSyncActor(accountKey);
    try {
      final profile = await _api.registerDevice(
        '',
        deviceId,
        deviceName,
        platform,
      );
      final result = ArmouryAccount(
        email: profile['email']?.toString() ?? email,
        accountKey: accountKey,
        status: profile['status']?.toString() ?? 'pending',
        role: profile['role']?.toString() ?? 'viewer',
      );
      _api.setIdentity(deviceId, canWrite: result.canEdit);
      await _dao.setSyncValue(
        'auth_profile_$accountKey',
        '${result.status}|${result.role}|${result.email}',
      );
      if (result.status == 'active') {
        await _dao.claimUnownedOperations(accountKey);
      }
      return result;
    } on ArmouryRemoteException catch (error) {
      // Explicit server denials must never fall back to a cached approval.
      if (error.statusCode != null) rethrow;
      return _cachedOfflineAccount(accountKey, email);
    } on Exception {
      return _cachedOfflineAccount(accountKey, email);
    }
  }

  Future<ArmouryAccount> _cachedOfflineAccount(
    String accountKey,
    String email,
  ) async {
    final cached = await _dao.getSyncValue('auth_profile_$accountKey');
    if (cached == null) {
      _api.clearIdentity();
      throw StateError(
        'Armoury cannot connect to Supabase. Connect to the internet and try again.',
      );
    }
    final parts = cached.split('|');
    final status = parts.isNotEmpty ? parts[0] : 'pending';
    final role = parts.length > 1 ? parts[1] : 'viewer';
    if (status != 'active') {
      _api.clearIdentity();
      throw StateError(
        'Connect to Armoury to check whether access is approved.',
      );
    }
    _dao.setSyncActor(accountKey);
    _api.setIdentity(
      _api.deviceId ?? '',
      canWrite: role == 'editor' || role == 'admin',
    );
    await _dao.claimUnownedOperations(accountKey);
    return ArmouryAccount(
      email: parts.length > 2 ? parts[2] : email,
      accountKey: accountKey,
      status: status,
      role: role,
      offline: true,
    );
  }

  Future<void> signOut() async {
    _api.clearIdentity();
    _dao.setSyncActor(null);
    await _api.client?.auth.signOut();
  }
}

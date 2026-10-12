import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gotrue/gotrue.dart'
    show AuthException, AuthRetryableFetchException;

import '../app_providers.dart';

enum AuthFailureAction { general, signUp, sendEmail }

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

class AuthState {
  final bool isLoading;
  final String? email;
  final String? accountKey;
  final String? status;
  final String? role;
  final bool offline;
  final bool emailConfirmationSent;
  final bool passwordRecoveryCodeSent;
  final bool passwordRecoveryComplete;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.email,
    this.accountKey,
    this.status,
    this.role,
    this.offline = false,
    this.emailConfirmationSent = false,
    this.passwordRecoveryCodeSent = false,
    this.passwordRecoveryComplete = false,
    this.error,
  });
  bool get isAuthenticated => email != null && status == 'active';
  bool get isPending => email != null && status == 'pending';
  bool get isDisabled => email != null && status == 'disabled';
  bool get canEdit => isAuthenticated && (role == 'editor' || role == 'admin');
  bool get isAdmin => isAuthenticated && role == 'admin';
}

class AuthViewModel extends Notifier<AuthState> {
  bool _checkingApproval = false;
  @override
  AuthState build() {
    ref.read(backendApiProvider).onAccessDenied = _handleAccessDenied;
    return const AuthState();
  }

  void _handleAccessDenied(String code) {
    if (code == 'account_pending' || code == 'account_disabled') {
      ref.read(syncCoordinatorProvider).stop();
      state = AuthState(
        email: state.email,
        accountKey: state.accountKey,
        status: code == 'account_pending' ? 'pending' : 'disabled',
        role: state.role,
        offline: false,
      );
    } else if (code == 'read_only') {
      state = AuthState(
        email: state.email,
        accountKey: state.accountKey,
        status: state.status,
        role: 'viewer',
        offline: false,
      );
    }
  }

  Future<void> restoreSession() async {
    state = const AuthState(isLoading: true);
    try {
      final account = await ref
          .read(supabaseAuthServiceProvider)
          .restoreSession();
      if (account?.canAccessInventory == true && !account!.offline) {
        ref.read(syncCoordinatorProvider).start(onSynchronized: () async {});
      }
      state = AuthState(
        email: account?.email,
        accountKey: account?.accountKey,
        status: account?.status,
        role: account?.role,
        offline: account?.offline ?? false,
      );
    } catch (error) {
      state = AuthState(error: _message(error));
    }
  }

  Future<void> checkApproval() async {
    if (_checkingApproval || !state.isPending) return;
    _checkingApproval = true;
    try {
      final account = await ref
          .read(supabaseAuthServiceProvider)
          .restoreSession();
      if (account == null) return;
      if (account.canAccessInventory && !account.offline) {
        ref.read(syncCoordinatorProvider).start();
        await ref.read(syncCoordinatorProvider).syncOnce();
      }
      state = AuthState(
        email: account.email,
        accountKey: account.accountKey,
        status: account.status,
        role: account.role,
        offline: account.offline,
      );
    } catch (_) {
      // Keep the waiting screen visible; the timer and resume callback retry.
    } finally {
      _checkingApproval = false;
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final account = await ref
          .read(supabaseAuthServiceProvider)
          .signIn(email, password);
      if (account.canAccessInventory && !account.offline) {
        ref.read(syncCoordinatorProvider).start();
        await ref.read(syncCoordinatorProvider).syncOnce();
      }
      state = AuthState(
        email: account.email,
        accountKey: account.accountKey,
        status: account.status,
        role: account.role,
        offline: account.offline,
      );
    } catch (error) {
      state = AuthState(error: _message(error));
    }
  }

  Future<void> signUp(String email, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final account = await ref
          .read(supabaseAuthServiceProvider)
          .signUp(email, password);
      if (account == null) {
        state = AuthState(email: email.trim(), emailConfirmationSent: true);
        return;
      }
      if (account.canAccessInventory && !account.offline) {
        ref.read(syncCoordinatorProvider).start(onSynchronized: () async {});
        await ref.read(syncCoordinatorProvider).syncOnce();
      }
      state = AuthState(
        email: account.email,
        accountKey: account.accountKey,
        status: account.status,
        role: account.role,
        offline: account.offline,
      );
    } catch (error) {
      state = AuthState(
        error: _message(error, action: AuthFailureAction.signUp),
      );
    }
  }

  Future<void> verifyEmailCode(String code) async {
    final email = state.email;
    if (email == null) return;
    state = AuthState(
      email: email,
      isLoading: true,
      emailConfirmationSent: true,
    );
    try {
      final account = await ref
          .read(supabaseAuthServiceProvider)
          .verifySignUpEmail(email, code);
      if (account.canAccessInventory && !account.offline) {
        ref.read(syncCoordinatorProvider).start(onSynchronized: () async {});
        await ref.read(syncCoordinatorProvider).syncOnce();
      }
      state = AuthState(
        email: account.email,
        accountKey: account.accountKey,
        status: account.status,
        role: account.role,
        offline: account.offline,
      );
    } catch (error) {
      state = AuthState(
        email: email,
        emailConfirmationSent: true,
        error: _message(error),
      );
    }
  }

  Future<void> resendEmailCode() async {
    final email = state.email;
    if (email == null) return;
    state = AuthState(
      email: email,
      isLoading: true,
      emailConfirmationSent: true,
    );
    try {
      await ref.read(supabaseAuthServiceProvider).resendSignUpCode(email);
      state = AuthState(email: email, emailConfirmationSent: true);
    } catch (error) {
      state = AuthState(
        email: email,
        emailConfirmationSent: true,
        error: _message(error),
      );
    }
  }

  Future<void> requestPasswordReset(String email) async {
    final normalizedEmail = email.trim();
    state = AuthState(isLoading: true, email: normalizedEmail);
    try {
      await ref
          .read(supabaseAuthServiceProvider)
          .requestPasswordReset(normalizedEmail);
      state = AuthState(email: normalizedEmail, passwordRecoveryCodeSent: true);
    } catch (error) {
      // Keep this response independent of whether the address has an account.
      state = AuthState(
        email: normalizedEmail,
        error: _message(error, action: AuthFailureAction.sendEmail),
      );
    }
  }

  Future<void> resendPasswordResetCode() async {
    final email = state.email;
    if (email == null) return;
    state = AuthState(
      email: email,
      isLoading: true,
      passwordRecoveryCodeSent: true,
    );
    try {
      await ref.read(supabaseAuthServiceProvider).requestPasswordReset(email);
      state = AuthState(email: email, passwordRecoveryCodeSent: true);
    } catch (error) {
      state = AuthState(
        email: email,
        passwordRecoveryCodeSent: true,
        error: _message(error, action: AuthFailureAction.sendEmail),
      );
    }
  }

  Future<void> completePasswordReset({
    required String code,
    required String newPassword,
  }) async {
    final email = state.email;
    if (email == null) return;
    state = AuthState(
      email: email,
      isLoading: true,
      passwordRecoveryCodeSent: true,
    );
    try {
      await ref
          .read(supabaseAuthServiceProvider)
          .completePasswordReset(
            email: email,
            token: code,
            newPassword: newPassword,
          );
      ref.read(syncCoordinatorProvider).stop();
      state = AuthState(email: email, passwordRecoveryComplete: true);
    } catch (error) {
      state = AuthState(
        email: email,
        passwordRecoveryCodeSent: true,
        error: _message(error),
      );
    }
  }

  void cancelPasswordRecovery() {
    state = AuthState(email: state.email);
  }

  Future<void> signOut() async {
    await ref.read(supabaseAuthServiceProvider).signOut();
    ref.read(syncCoordinatorProvider).stop();
    state = const AuthState();
  }

  void clearEmailConfirmation() {
    state = const AuthState();
  }

  void setError(String message) {
    state = AuthState(
      email: state.email,
      accountKey: state.accountKey,
      status: state.status,
      role: state.role,
      offline: state.offline,
      emailConfirmationSent: state.emailConfirmationSent,
      passwordRecoveryCodeSent: state.passwordRecoveryCodeSent,
      passwordRecoveryComplete: state.passwordRecoveryComplete,
      error: message,
    );
  }

  String _message(
    Object error, {
    AuthFailureAction action = AuthFailureAction.general,
  }) => friendlyAuthErrorMessage(error, action: action);
}

/// Converts SDK and transport exceptions into concise messages suitable for
/// the sign-in screen. Raw exception strings include implementation details
/// and can be thousands of characters long.
String friendlyAuthErrorMessage(
  Object error, {
  AuthFailureAction action = AuthFailureAction.general,
}) {
  if (error is AuthRetryableFetchException) {
    return 'Could not reach Armoury. Check your internet connection and try again. For a phone using local development, connect it to the computer’s network and use the computer’s LAN address.';
  }
  if (error is AuthException) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'user_already_registered' ||
        message.contains('user already registered') ||
        message.contains('email already exists') ||
        message.contains('already registered')) {
      return 'An account with this email already exists. Sign in or use Forgot Password.';
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'That email and password do not match. Check them and try again.';
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Confirm your email with the code before signing in.';
    }
    if (code == 'weak_password') {
      return 'Choose a stronger password and try again.';
    }
    if ((code?.contains('rate_limit') ?? false) ||
        message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('email send limit')) {
      return 'Too many emails were requested. Wait before trying again.';
    }
    if (message.contains('email address not authorized') ||
        code == 'email_address_not_authorized' ||
        message.contains('email provider is not enabled') ||
        message.contains('smtp') ||
        code == 'email_provider_disabled') {
      return 'Supabase Auth could not send the email. Configure custom SMTP in the hosted project’s Authentication settings.';
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return 'That code has expired. Request a new code and try again.';
    }
    if (code == 'otp_disabled' || message.contains('invalid otp')) {
      return 'That code is invalid. Check the latest email or request a new code.';
    }
    if (action == AuthFailureAction.sendEmail) {
      return 'Supabase refused to send the email. Check Authentication > SMTP and the matching email template in the hosted project.';
    }
    if (message.contains('socketexception') ||
        message.contains('connection refused') ||
        message.contains('failed host lookup') ||
        message.contains('timed out')) {
      return 'Could not reach Armoury. Check your connection and try again. A phone using local development must use the computer’s LAN address, not 127.0.0.1.';
    }
    return 'Armoury could not complete that request. Check your details and try again.';
  }

  final message = error.toString().toLowerCase();
  if (action == AuthFailureAction.signUp &&
      (message.contains('did not create the account') ||
          message.contains('did not create an account'))) {
    return 'Could not create the account. Check the email and password, then try again.';
  }
  if (message.contains('supabase is not configured')) {
    return 'This app build is not connected to Armoury yet. Install the configured app build or contact the person who shared it.';
  }
  if (message.contains('socketexception') ||
      message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('timed out') ||
      message.contains('127.0.0.1') ||
      message.contains('localhost')) {
    return 'Could not reach Armoury. Check your connection and try again. A phone using local development must use the computer’s LAN address, not 127.0.0.1.';
  }
  if (action == AuthFailureAction.sendEmail) {
    return 'Could not request the reset email. Check your connection and try again. If this continues, check Supabase Auth email logs and SMTP settings.';
  }
  return 'Armoury could not complete that request. Please try again.';
}

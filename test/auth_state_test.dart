import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart'
    show AuthApiException, AuthRetryableFetchException;
import 'package:armoury_flutter/providers/viewmodels/auth_viewmodel.dart';

void main() {
  group('account role capabilities', () {
    test('email code confirmation alone does not grant inventory access', () {
      const state = AuthState(
        email: 'new@example.com',
        emailConfirmationSent: true,
      );
      expect(state.emailConfirmationSent, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isPending, isFalse);
    });

    test('password recovery code state grants no account access', () {
      const state = AuthState(
        email: 'user@example.com',
        passwordRecoveryCodeSent: true,
      );
      expect(state.passwordRecoveryCodeSent, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isPending, isFalse);
      expect(state.canEdit, isFalse);
      expect(state.isAdmin, isFalse);
    });

    test('completed password recovery still requires a fresh sign-in', () {
      const state = AuthState(
        email: 'user@example.com',
        passwordRecoveryComplete: true,
      );
      expect(state.passwordRecoveryComplete, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isPending, isFalse);
      expect(state.accountKey, isNull);
    });

    test('pending account has no inventory or edit access', () {
      const state = AuthState(
        email: 'new@example.com',
        status: 'pending',
        role: 'viewer',
      );
      expect(state.isPending, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.canEdit, isFalse);
      expect(state.isAdmin, isFalse);
    });

    test('viewer can enter inventory but cannot edit or administer', () {
      const state = AuthState(
        email: 'view@example.com',
        status: 'active',
        role: 'viewer',
      );
      expect(state.isAuthenticated, isTrue);
      expect(state.canEdit, isFalse);
      expect(state.isAdmin, isFalse);
    });

    test('editor can change inventory but cannot administer', () {
      const state = AuthState(
        email: 'edit@example.com',
        status: 'active',
        role: 'editor',
      );
      expect(state.canEdit, isTrue);
      expect(state.isAdmin, isFalse);
    });

    test('admin can edit and manage access', () {
      const state = AuthState(
        email: 'admin@example.com',
        status: 'active',
        role: 'admin',
      );
      expect(state.canEdit, isTrue);
      expect(state.isAdmin, isTrue);
    });
  });

  group('auth error messages', () {
    test('invalid credentials do not expose SDK exception details', () {
      final message = friendlyAuthErrorMessage(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(message, contains('email and password do not match'));
      expect(message, isNot(contains('AuthApiException')));
      expect(message, isNot(contains('statusCode')));
    });

    test('connection failures explain the local phone address issue', () {
      final message = friendlyAuthErrorMessage(
        AuthRetryableFetchException(
          message: 'SocketException: Connection refused at 127.0.0.1',
        ),
      );
      expect(message, contains('computer’s network'));
      expect(message, isNot(contains('SocketException')));
    });

    test('duplicate signup response gives a direct next step', () {
      final message = friendlyAuthErrorMessage(
        const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'email_exists',
        ),
        action: AuthFailureAction.signUp,
      );
      expect(message, contains('account with this email already exists'));
      expect(message, contains('Forgot Password'));
    });

    test('email delivery configuration failures identify SMTP setup', () {
      final message = friendlyAuthErrorMessage(
        const AuthApiException(
          'Email address not authorized',
          statusCode: '403',
          code: 'email_address_not_authorized',
        ),
        action: AuthFailureAction.sendEmail,
      );
      expect(message, contains('custom SMTP'));
    });

    test('email rate limits tell the user to wait', () {
      final message = friendlyAuthErrorMessage(
        const AuthApiException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
        action: AuthFailureAction.sendEmail,
      );
      expect(message, contains('Wait before trying again'));
    });

    test('unexpected reset email failures get actionable guidance', () {
      final message = friendlyAuthErrorMessage(
        StateError('unexpected transport response'),
        action: AuthFailureAction.sendEmail,
      );
      expect(message, contains('Could not request the reset email'));
      expect(message, contains('Supabase Auth email logs'));
      expect(message, isNot(contains('unexpected transport response')));
    });
  });
}

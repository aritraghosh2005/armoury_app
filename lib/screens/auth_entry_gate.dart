import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/viewmodels/auth_viewmodel.dart';
import '../widgets/optical_glass_slab.dart';
import '../widgets/orcus_wallpaper.dart';
import '../widgets/terminal_button.dart';
import 'app_shell.dart';

class AuthEntryGate extends ConsumerStatefulWidget {
  const AuthEntryGate({super.key});

  @override
  ConsumerState<AuthEntryGate> createState() => _AuthEntryGateState();
}

class _AuthEntryGateState extends ConsumerState<AuthEntryGate>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  Timer? _approvalTimer;
  bool _creatingAccount = false;
  bool _forgotPassword = false;
  bool _hidePassword = true;
  bool _hideNewPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _approvalTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ref.read(authViewModelProvider).isPending) {
        ref.read(authViewModelProvider.notifier).checkApproval();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authViewModelProvider.notifier).restoreSession();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authViewModelProvider).isPending) {
      ref.read(authViewModelProvider.notifier).checkApproval();
    }
  }

  @override
  void dispose() {
    _approvalTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _recoveryCodeController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    if (auth.isAuthenticated) return const AppShell();
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const OrcusWallpaper(),
          // Keep the slab on the full, stable screen canvas while the IME is
          // open. Only the form inside it scrolls; shrinking this Positioned
          // area makes the glass itself jump/rescale with the keyboard.
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: OpticalGlassSlab(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _forgotPassword
                                    ? auth.passwordRecoveryCodeSent
                                          ? 'ARMOURY // RESET PASSWORD'
                                          : 'ARMOURY // RECOVER ACCESS'
                                    : auth.emailConfirmationSent
                                    ? 'ARMOURY // CONFIRM EMAIL'
                                    : auth.isPending
                                    ? 'ARMOURY // ACCESS REQUEST'
                                    : auth.isDisabled
                                    ? 'ARMOURY // ACCESS DISABLED'
                                    : 'ARMOURY // SHARED INVENTORY',
                                textAlign: TextAlign.center,
                                style: AppTypography.title(),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _forgotPassword
                                    ? auth.passwordRecoveryCodeSent
                                          ? 'Enter the code sent to your email, then choose a new password.'
                                          : 'Enter your account email and we’ll send a password reset code if an account exists.'
                                    : auth.emailConfirmationSent
                                    ? 'If this address is new, enter the code sent to your email. If you already have an account, sign in or use Forgot Password. Email confirmation does not replace admin approval.'
                                    : auth.isPending
                                    ? 'Please wait for your account to be approved. You can leave this screen; Armoury will check again automatically when you return.'
                                    : auth.isDisabled
                                    ? 'This account currently cannot access Armoury. Use another approved account or contact the person who shared the app with you.'
                                    : _creatingAccount
                                    ? 'Create an Armoury account with your email. After you confirm it, the admin must approve your access before you can open inventory.'
                                    : 'Sign in with your Armoury email account. New accounts need admin approval before opening the inventory.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(color: AppColors.dim),
                              ),
                              if (auth.passwordRecoveryComplete &&
                                  !_forgotPassword) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'PASSWORD UPDATED. SIGN IN WITH YOUR NEW PASSWORD.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption(
                                    color: AppColors.fg,
                                  ),
                                ),
                              ],
                              if (auth.isPending) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'ACCOUNT: ${auth.email}\nPLEASE WAIT FOR APPROVAL',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.mono(
                                    fontSize: 10,
                                    color: AppColors.fg,
                                  ),
                                ),
                              ],
                              if (auth.emailConfirmationSent ||
                                  (_forgotPassword &&
                                      auth.passwordRecoveryCodeSent)) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _forgotPassword
                                      ? 'RESET CODE SENT TO: ${auth.email}'
                                      : 'CHECK EMAIL IF THIS IS A NEW ACCOUNT: ${auth.email}',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.mono(
                                    fontSize: 10,
                                    color: AppColors.fg,
                                  ),
                                ),
                              ],
                              if (auth.offline) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'OFFLINE ACCESS · ${auth.role?.toUpperCase() ?? 'VIEWER'}',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption(
                                    color: AppColors.dim,
                                  ),
                                ),
                              ],
                              if (auth.error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  auth.error!,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    color: AppColors.purgeRed,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              if (auth.isPending)
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'CHECKING APPROVAL',
                                          style: AppTypography.caption(
                                            color: AppColors.dim,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TerminalButton(
                                      label: 'SIGN OUT',
                                      onPressed: () => ref
                                          .read(authViewModelProvider.notifier)
                                          .signOut(),
                                    ),
                                  ],
                                )
                              else if (auth.emailConfirmationSent)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _otpController,
                                      enabled: !auth.isLoading,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 10,
                                      decoration: const InputDecoration(
                                        labelText: 'EMAIL CODE',
                                        counterText: '',
                                      ),
                                      onSubmitted: (_) =>
                                          _verifyCode(auth.isLoading),
                                    ),
                                    const SizedBox(height: 14),
                                    TerminalButton(
                                      label: auth.isLoading
                                          ? 'VERIFYING'
                                          : 'VERIFY EMAIL',
                                      onPressed: auth.isLoading
                                          ? null
                                          : () => _verifyCode(false),
                                      variant: TerminalButtonVariant.primary,
                                    ),
                                    TextButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : () => ref
                                                .read(
                                                  authViewModelProvider
                                                      .notifier,
                                                )
                                                .resendEmailCode(),
                                      child: Text(
                                        'RESEND CODE',
                                        style: AppTypography.caption(
                                          color: AppColors.fg,
                                        ),
                                      ),
                                    ),
                                    TerminalButton(
                                      label: 'BACK TO SIGN IN',
                                      onPressed: auth.isLoading
                                          ? null
                                          : () {
                                              ref
                                                  .read(
                                                    authViewModelProvider
                                                        .notifier,
                                                  )
                                                  .clearEmailConfirmation();
                                              _otpController.clear();
                                              setState(
                                                () => _creatingAccount = false,
                                              );
                                            },
                                    ),
                                  ],
                                )
                              else if (_forgotPassword)
                                _passwordRecoveryForm(auth)
                              else ...[
                                TextField(
                                  controller: _emailController,
                                  enabled: !auth.isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  style: AppTypography.mono(
                                    fontSize: 13,
                                    letterSpacing: 0,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'EMAIL',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordController,
                                  enabled: !auth.isLoading,
                                  obscureText: _hidePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(auth.isLoading),
                                  decoration: InputDecoration(
                                    labelText: 'PASSWORD',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TerminalButton(
                                  label: auth.isLoading
                                      ? 'CONNECTING'
                                      : _creatingAccount
                                      ? 'CREATE ACCOUNT'
                                      : 'SIGN IN',
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => _submit(false),
                                  variant: TerminalButtonVariant.primary,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => setState(
                                          () => _creatingAccount =
                                              !_creatingAccount,
                                        ),
                                  child: Text(
                                    _creatingAccount
                                        ? 'ALREADY REGISTERED? SIGN IN'
                                        : 'NEW HERE? CREATE ACCOUNT',
                                    style: AppTypography.caption(
                                      color: AppColors.fg,
                                    ),
                                  ),
                                ),
                                if (!_creatingAccount)
                                  TextButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () {
                                            ref
                                                .read(
                                                  authViewModelProvider
                                                      .notifier,
                                                )
                                                .cancelPasswordRecovery();
                                            setState(
                                              () => _forgotPassword = true,
                                            );
                                          },
                                    child: Text(
                                      'FORGOT PASSWORD?',
                                      style: AppTypography.caption(
                                        color: AppColors.dim,
                                      ),
                                    ),
                                  ),
                                if (auth.isDisabled) ...[
                                  const SizedBox(height: 6),
                                  TerminalButton(
                                    label: 'SIGN OUT',
                                    onPressed: () => ref
                                        .read(authViewModelProvider.notifier)
                                        .signOut(),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRecoveryForm(AuthState auth) {
    if (auth.passwordRecoveryComplete) {
      return Column(
        children: [
          Text(
            'PASSWORD UPDATED. SIGN IN WITH YOUR NEW PASSWORD.',
            textAlign: TextAlign.center,
            style: AppTypography.mono(fontSize: 10, color: AppColors.fg),
          ),
          const SizedBox(height: 16),
          TerminalButton(
            label: 'BACK TO SIGN IN',
            onPressed: auth.isLoading ? null : _leavePasswordRecovery,
            variant: TerminalButtonVariant.primary,
          ),
        ],
      );
    }

    if (!auth.passwordRecoveryCodeSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            enabled: !auth.isLoading,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppTypography.mono(fontSize: 13, letterSpacing: 0),
            decoration: const InputDecoration(
              labelText: 'EMAIL',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 18),
          TerminalButton(
            label: auth.isLoading ? 'SENDING CODE' : 'SEND RESET CODE',
            onPressed: auth.isLoading ? null : _requestPasswordReset,
            variant: TerminalButtonVariant.primary,
          ),
          TextButton(
            onPressed: auth.isLoading ? null : _leavePasswordRecovery,
            child: Text(
              'BACK TO SIGN IN',
              style: AppTypography.caption(color: AppColors.fg),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _recoveryCodeController,
          enabled: !auth.isLoading,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'RESET CODE',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordController,
          enabled: !auth.isLoading,
          obscureText: _hideNewPassword,
          decoration: InputDecoration(
            labelText: 'NEW PASSWORD',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _hideNewPassword = !_hideNewPassword),
              icon: Icon(
                _hideNewPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmNewPasswordController,
          enabled: !auth.isLoading,
          obscureText: _hideNewPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _completePasswordReset(auth.isLoading),
          decoration: const InputDecoration(
            labelText: 'CONFIRM NEW PASSWORD',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 18),
        TerminalButton(
          label: auth.isLoading ? 'UPDATING PASSWORD' : 'UPDATE PASSWORD',
          onPressed: auth.isLoading
              ? null
              : () => _completePasswordReset(false),
          variant: TerminalButtonVariant.primary,
        ),
        TextButton(
          onPressed: auth.isLoading
              ? null
              : () => ref
                    .read(authViewModelProvider.notifier)
                    .resendPasswordResetCode(),
          child: Text(
            'RESEND CODE',
            style: AppTypography.caption(color: AppColors.fg),
          ),
        ),
        TextButton(
          onPressed: auth.isLoading ? null : _leavePasswordRecovery,
          child: Text(
            'BACK TO SIGN IN',
            style: AppTypography.caption(color: AppColors.dim),
          ),
        ),
      ],
    );
  }

  void _requestPasswordReset() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('Enter a valid email address.');
      return;
    }
    ref.read(authViewModelProvider.notifier).requestPasswordReset(email);
  }

  void _completePasswordReset(bool isLoading) {
    if (isLoading) return;
    final code = _recoveryCodeController.text.trim();
    final password = _newPasswordController.text;
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('Enter the email code from your latest message.');
      return;
    }
    if (password.length < 8) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('Password must be at least 8 characters.');
      return;
    }
    if (password != _confirmNewPasswordController.text) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('The passwords do not match.');
      return;
    }
    ref
        .read(authViewModelProvider.notifier)
        .completePasswordReset(code: code, newPassword: password);
  }

  void _leavePasswordRecovery() {
    ref.read(authViewModelProvider.notifier).cancelPasswordRecovery();
    _recoveryCodeController.clear();
    _newPasswordController.clear();
    _confirmNewPasswordController.clear();
    setState(() => _forgotPassword = false);
  }

  void _submit(bool isLoading) {
    if (isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('Enter a valid email address.');
      return;
    }
    if (password.isEmpty || (_creatingAccount && password.length < 8)) {
      ref
          .read(authViewModelProvider.notifier)
          .setError(
            _creatingAccount
                ? 'Password must be at least 8 characters.'
                : 'Enter your password.',
          );
      return;
    }
    final auth = ref.read(authViewModelProvider.notifier);
    if (_creatingAccount) {
      auth.signUp(email, password);
    } else {
      auth.signIn(email, password);
    }
  }

  void _verifyCode(bool isLoading) {
    if (isLoading) return;
    final code = _otpController.text.trim();
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      ref
          .read(authViewModelProvider.notifier)
          .setError('Enter the email code from your latest message.');
      return;
    }
    ref.read(authViewModelProvider.notifier).verifyEmailCode(code);
  }
}

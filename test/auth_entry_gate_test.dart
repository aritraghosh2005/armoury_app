import 'package:armoury_flutter/providers/viewmodels/auth_viewmodel.dart';
import 'package:armoury_flutter/screens/auth_entry_gate.dart';
import 'package:armoury_flutter/widgets/animated_orcus_logo.dart';
import 'package:armoury_flutter/widgets/optical_glass_slab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signup confirmation accepts an eight-digit Supabase OTP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(
            () => _SignedOutAuthViewModel(
              initialState: const AuthState(
                email: 'user@example.com',
                emailConfirmationSent: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthEntryGate()),
      ),
    );
    await tester.pump();

    final codeField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'EMAIL CODE',
    );
    await tester.ensureVisible(codeField);
    expect(tester.widget<TextField>(codeField).maxLength, 10);
    await tester.enterText(codeField, '12345678');
    expect(tester.widget<TextField>(codeField).controller?.text, '12345678');
  });

  testWidgets('password recovery accepts an eight-digit Supabase OTP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(
            () => _SignedOutAuthViewModel(
              initialState: const AuthState(email: 'user@example.com'),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthEntryGate()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pump();
    final emailField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'EMAIL',
    );
    await tester.enterText(emailField, 'user@example.com');
    await tester.tap(find.text('[ SEND RESET CODE ]'));
    await tester.pump();

    final codeField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'RESET CODE',
    );
    await tester.ensureVisible(codeField);
    expect(tester.widget<TextField>(codeField).maxLength, 10);
    await tester.enterText(codeField, '12345678');
    expect(tester.widget<TextField>(codeField).controller?.text, '12345678');
  });

  testWidgets('keyboard leaves the wallpaper mark fixed and form scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _SignedOutAuthViewModel()),
        ],
        child: const MaterialApp(home: AuthEntryGate()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final logoFinder = find.byType(AnimatedOrcusLogo);
    final slabFinder = find.byType(OpticalGlassSlab);
    expect(logoFinder, findsOneWidget);
    expect(slabFinder, findsOneWidget);
    final initialLogoRect = tester.getRect(logoFinder);
    final initialSlabRect = tester.getRect(slabFinder);

    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('[ SEND RESET CODE ]'), findsOneWidget);
    expect(tester.getRect(logoFinder), initialLogoRect);
    expect(tester.getRect(slabFinder), initialSlabRect);
  });
}

class _SignedOutAuthViewModel extends AuthViewModel {
  _SignedOutAuthViewModel({this.initialState = const AuthState()});

  final AuthState initialState;

  @override
  AuthState build() => initialState;

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> requestPasswordReset(String email) async {
    state = AuthState(email: email, passwordRecoveryCodeSent: true);
  }
}

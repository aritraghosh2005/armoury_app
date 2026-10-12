import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:armoury_flutter/main.dart';
import 'package:armoury_flutter/providers/viewmodels/armoury_viewmodel.dart';
import 'package:armoury_flutter/providers/viewmodels/auth_viewmodel.dart';

import 'package:armoury_flutter/widgets/animated_orcus_logo.dart';

import 'package:armoury_flutter/providers/tutorial_provider.dart';
import 'package:armoury_flutter/providers/viewmodels/archive_viewmodel.dart';

void main() {
  testWidgets('App shell smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          armouryViewModelProvider.overrideWith(() => _EmptyArmouryViewModel()),
          authViewModelProvider.overrideWith(() => _ApprovedAuthViewModel()),
          tutorialProvider.overrideWith(() => _CompletedTutorialNotifier()),
          archiveItemsProvider.overrideWith(
            (ref) async => <Map<String, dynamic>>[],
          ),
        ],
        child: const ArmouryApp(),
      ),
    );

    await tester.pump();
    if (find.textContaining('USE OFFLINE').evaluate().isNotEmpty) {
      await tester.tap(find.textContaining('USE OFFLINE'));
    }
    await tester.pump(const Duration(milliseconds: 200));

    // Verify title and nav elements render
    expect(find.text('TEAM ORCUS'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('CRATE'), findsWidgets);
    expect(find.text('TOOLKIT'), findsWidgets);
    expect(find.text('CUPBOARD'), findsWidgets);

    // Main screen settings begins at the right edge.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.settings_outlined)).dx,
      greaterThan(320),
    );

    // Verify Animated Orcus character logo in background
    expect(find.byType(AnimatedOrcusLogo), findsOneWidget);

    // Tap wheel icon and verify 65% glass pane slides in from right
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // The same control travels to the left and becomes the circled-X escape.
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('escape-settings')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('escape-settings'))).dx,
      lessThan(100),
    );
    expect(find.text('← CONFIG'), findsNothing);
    final paneHeaderHeight = tester
        .getSize(find.byKey(const ValueKey('settings-pane-header')))
        .height;
    expect(paneHeaderHeight, 36);

    // Verify contents of the settings screen inside the sliding glass pane
    expect(find.text('CONFIG'), findsWidgets);
    expect(find.text('DISPLAY THEME'), findsOneWidget);
    expect(find.text('INVENTORY LIST'), findsOneWidget);
    expect(find.text('DOWNLOAD INVENTORY + PHOTOS (.ZIP)'), findsOneWidget);
    expect(find.textContaining('IMPORT BACKUP'), findsNothing);
    expect(find.text('j0K3r'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-admin')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-archive')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('j0K3r'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('restored from Archive'), findsNothing);
    expect(tester.getTopLeft(find.text('DISPLAY THEME')).dy, lessThan(260));

    await tester.tap(find.byKey(const ValueKey('open-archive')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-pane-header'))).height,
      paneHeaderHeight,
    );
    expect(find.text('DELETED COMPONENTS'), findsOneWidget);
    expect(find.textContaining('stay here for up to 7 days'), findsOneWidget);
    expect(find.textContaining('ARCHIVE IS EMPTY'), findsOneWidget);
    expect(find.text('j0K3r'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('back-to-config')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-config')));
    await tester.pumpAndSettle();
    expect(find.text('INVENTORY LIST'), findsOneWidget);

    // The circled-X escape closes the pane and returns the gear to the right.
    await tester.tap(find.byKey(const ValueKey('escape-settings')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('escape-settings')), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.settings_outlined)).dx,
      greaterThan(320),
    );

    // Double-tap an unoccupied inventory area to open search.
    const searchPoint = Offset(180, 420);
    await tester.tapAt(searchPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(searchPoint);
    await tester.pumpAndSettle();
    expect(find.text('SEARCHING'), findsOneWidget);
  });
}

class _EmptyArmouryViewModel extends ArmouryViewModel {
  @override
  Future<ArmouryState> build() async => const ArmouryState();
}

class _CompletedTutorialNotifier extends TutorialNotifier {
  @override
  bool build() => true;
}

class _ApprovedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() => const AuthState(
    email: 'approved@example.invalid',
    status: 'active',
    role: 'admin',
  );

  @override
  Future<void> restoreSession() async {}
}

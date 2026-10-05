import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:armoury_flutter/main.dart';
import 'package:armoury_flutter/providers/viewmodels/armoury_viewmodel.dart';

import 'package:armoury_flutter/widgets/animated_orcus_logo.dart';

import 'package:armoury_flutter/providers/tutorial_provider.dart';

void main() {
  testWidgets('App shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          armouryViewModelProvider.overrideWith(() => _EmptyArmouryViewModel()),
          tutorialProvider.overrideWith(() => _CompletedTutorialNotifier()),
        ],
        child: const ArmouryApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify title and nav elements render
    expect(find.text('TEAM ORCUS'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('CRATE'), findsWidgets);
    expect(find.text('TOOLKIT'), findsWidgets);
    expect(find.text('CUPBOARD'), findsWidgets);

    // Dismiss initial backup prompt if displayed
    final emptyRepoBtn = find.text('START WITH NEW EMPTY REPOSITORY >>');
    if (emptyRepoBtn.evaluate().isNotEmpty) {
      await tester.tap(emptyRepoBtn);
      await tester.pumpAndSettle();
    }

    // Verify Settings button is present with ONLY the wheel icon
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Verify Animated Orcus character logo in background
    expect(find.byType(AnimatedOrcusLogo), findsOneWidget);

    // Tap wheel icon and verify 65% glass pane slides in from right
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify button changed to Home icon
    expect(find.byIcon(Icons.home_outlined), findsWidgets);

    // Verify contents of the settings screen inside the sliding glass pane
    expect(find.text('CONFIG'), findsWidgets);
    expect(find.text('DISPLAY THEME'), findsOneWidget);
    expect(find.text('BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('EXPORT BACKUP (.ZIP)'), findsOneWidget);
    expect(find.text('IMPORT BACKUP (.ZIP)'), findsOneWidget);

    // Tap Home icon and verify glass pane slides away, button changes back to wheel icon
    await tester.tap(find.byIcon(Icons.home_outlined).last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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

import 'package:baby_app/src/ui/update_card.dart';
import 'package:baby_app/src/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PlayUpdates extends AppUpdates {
  @override
  bool get usesPlayStore => true;
  int checks = 0;
  int storeOpens = 0;

  @override
  Future<void> check({bool manual = false}) async => checks++;

  @override
  Future<void> openStore() async => storeOpens++;
}

void main() {
  testWidgets('Play version dialog opens the store without checking GitHub', (
    tester,
  ) async {
    final updates = _PlayUpdates();
    addTearDown(updates.dispose);
    // Even a stale GitHub release must never expose an installer in Play UI.
    updates.available = AppRelease('9.0.0', Uri.parse(releaseRepository), 123);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppUpdates(context, updates: updates),
              child: const Text('Version'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();
    expect(updates.checks, 0);
    expect(
      find.text('Updates for this version are provided by Google Play.'),
      findsOneWidget,
    );
    expect(find.text('Update'), findsNothing);
    expect(find.textContaining('New update available'), findsNothing);
    expect(find.textContaining('Download from GitHub'), findsNothing);
    await tester.tap(find.text('Open Google Play'));
    expect(updates.storeOpens, 1);
  });

  test('flavor selection is supplied by Flutter at build time', () {
    const flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
    final updates = AppUpdates();
    addTearDown(updates.dispose);
    expect(updates.usesPlayStore, flavor == 'play');
  });
}

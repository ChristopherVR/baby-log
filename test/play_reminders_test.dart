import 'package:baby_app/src/background.dart';
import 'package:baby_app/src/distribution.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _picker() => MaterialApp(
  home: Scaffold(
    body: RingStylePicker(alarm: false, onChanged: (_) {}),
  ),
);

void main() {
  final original = Distribution.play;
  tearDown(() => Distribution.play = original);

  testWidgets('GitHub build lets you choose notification or alarm', (
    tester,
  ) async {
    Distribution.play = false;
    await tester.pumpWidget(_picker());
    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
  });

  testWidgets('Play build hides the notification/alarm choice', (tester) async {
    Distribution.play = true;
    await tester.pumpWidget(_picker());
    expect(find.text('Notification'), findsNothing);
    expect(find.text('Alarm'), findsNothing);
  });

  test('Play build never asks for the battery optimisation exemption', () {
    Distribution.play = true;
    expect(BackgroundSync.batteryExemptSupported, isFalse);
  });
}

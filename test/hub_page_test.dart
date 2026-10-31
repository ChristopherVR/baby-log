import 'dart:io';

import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:baby_app/src/ui/common.dart';
import 'package:baby_app/src/ui/hub_page.dart';
import 'package:baby_app/src/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the sync chip opens the hub view', (tester) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('baby-hub-ui-'),
    ))!;
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(File('${dir.path}/app.json')),
    ))!;
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(() async {
        await app.pendingSave;
        await dir.delete(recursive: true);
      });
    });
    app.peers.add(
      Peer(
        deviceId: 'x',
        host: '10.0.0.2',
        port: 8765,
        key: '123456',
        name: 'Dad',
      ),
    );
    for (final empty in [false, true]) {
      if (empty) app.peers.clear();
      await tester.pumpWidget(
        AppScope(
          key: UniqueKey(),
          state: app,
          child: MaterialApp(
            home: Scaffold(appBar: AppBar(actions: const [SyncChip()])),
          ),
        ),
      );
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(find.byType(HubPage), findsOneWidget);
      expect(find.textContaining('This device'), findsOneWidget);
      expect(find.text(empty ? 'No other devices yet' : 'Dad'), findsOneWidget);
      expect(find.text('Add a device'), findsOneWidget);
      await tester.ensureVisible(find.text('Add a device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a device'));
      await tester.pumpAndSettle();
      expect(find.byType(AddDevicePage), findsOneWidget);
    }
  });
}

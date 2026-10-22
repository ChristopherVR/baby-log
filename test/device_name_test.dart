import 'dart:convert';
import 'dart:io';

import 'package:baby_app/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> loadWith(Directory dir, Map<String, Object?> json) async {
    final file = File('${dir.path}/app.json');
    await file.writeAsString(jsonEncode(json));
    return AppState.loadForTesting(file);
  }

  test(
    'only names typed by the user are kept over the device\'s own',
    () async {
      final dir = await Directory.systemTemp.createTemp('device-name-test-');
      try {
        final old = await loadWith(dir, {'deviceName': 'Phone'});
        expect(old.deviceNameCustom, isFalse);
        old.dispose();

        final typed = await loadWith(dir, {'deviceName': "Dad's phone"});
        expect(typed.deviceNameCustom, isTrue);
        typed.dispose();

        final app = await loadWith(dir, {
          'deviceName': 'Pixel 8',
          'deviceNameCustom': false,
        });
        app.setDeviceName('  ');
        expect((app.deviceName, app.deviceNameCustom), ('Pixel 8', false));
        app.setDeviceName(' Kitchen tablet ');
        expect(
          (app.deviceName, app.deviceNameCustom),
          ('Kitchen tablet', true),
        );
        await app.pendingSave;
        final reloaded = await AppState.loadForTesting(
          File('${dir.path}/app.json'),
        );
        expect(reloaded.deviceNameCustom, isTrue);
        expect(reloaded.nightLight, isTrue);
        app.dispose();
        reloaded.dispose();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}

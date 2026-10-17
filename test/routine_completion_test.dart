import 'dart:convert';
import 'dart:io';

import 'package:baby_app/src/qr_transfer.dart';
import 'package:baby_app/src/routines.dart';
import 'package:baby_app/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AppState app;
  final others = <AppState>[];
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('routine-completion-test-');
    app = await AppState.loadForTesting(File('${dir.path}/app.json'));
    AppState.appVersion = '1.4.0';
  });
  tearDown(() async {
    for (final state in [app, ...others]) {
      state.dispose();
      await state.pendingSave;
    }
    others.clear();
    await dir.delete(recursive: true);
  });

  Routine bath() {
    final r = Routine(babyId: defaultBabyId, name: 'Bath time');
    app.saveRoutine(r);
    return r;
  }

  test('records who actually did it, time and baby independently of selected profile', () {
    final r = bath();
    final at = DateTime.now().subtract(const Duration(hours: 2));
    app.addBaby('Robin');
    final c = app.completeRoutine(r, doneBy: ' Dad ', time: at)!;
    expect(c.doneBy, 'Dad');
    expect(c.deviceId, app.deviceId);
    expect(c.time, at);
    expect(c.babyId, defaultBabyId);
    expect(app.routineHistory(), isEmpty);
    expect(app.lastRoutineCompletion(r)?.id, c.id);
    app.selectBaby(defaultBabyId);
    expect(app.routineHistory().single.id, c.id);
    expect(app.caregiverName, 'Dad');
    expect(RoutineCompletion.fromJson(c.toJson())!.toJson(), c.toJson());
    expect(app.completeRoutine(r, doneBy: '  '), isNull);
    expect(
      app.completeRoutine(
        r,
        doneBy: 'Dad',
        time: DateTime.now().add(const Duration(days: 1)),
      ),
      isNull,
    );
  });

  test(
    'last done uses activity time, and undo restores the earlier completion',
    () {
      final r = bath();
      final recent = app.completeRoutine(r, doneBy: 'Mum')!;
      final earlier = app.completeRoutine(
        r,
        doneBy: 'Dad',
        time: recent.time.subtract(const Duration(days: 2)),
      )!;
      expect(app.lastRoutineCompletion(r)?.id, recent.id);
      app.setRoutineCompletionDeleted(recent, true);
      expect(app.lastRoutineCompletion(r)?.id, earlier.id);
      app.setRoutineCompletionDeleted(recent, false);
      expect(app.lastRoutineCompletion(r)?.id, recent.id);
      final now = DateTime.now();
      expect(
        app.nextRoutineAt(r, now),
        DateTime(now.year, now.month, now.day + 1, 18),
      );
    },
  );

  test('history survives schedule deletion, restart and backup without leaking local caregiver preference', () async {
    final r = bath();
    final c = app.completeRoutine(r, doneBy: 'Grandma')!;
    app.saveRoutine(r.copyWith(deleted: true));
    expect(app.completeRoutine(r, doneBy: 'Dad'), isNull);
    expect(app.routineHistory().single.routineName, 'Bath time');
    await app.pendingSave;
    final loaded = await AppState.loadForTesting(File(app.dataFilePath));
    others.add(loaded);
    expect(loaded.routineHistory().single.toJson(), c.toJson());
    expect(loaded.caregiverName, 'Grandma');
    final copy = await AppState.loadForTesting(File('${dir.path}/copy.json'));
    others.add(copy);
    expect(copy.importBackup(app.exportBackup()).completions, 1);
    expect(copy.caregiverName, isEmpty);
    expect(copy.routineHistory().single.doneBy, 'Grandma');
    expect(copy.importBackup(app.exportBackup()).completions, 0);
    final backup = jsonDecode(app.exportBackup()) as Map<String, dynamic>;
    expect(backup.containsKey('caregiverName'), isFalse);
  });

  test(
    'QR transfers completions, removals and undo without duplicating history',
    () async {
      final r = bath();
      final c = app.completeRoutine(r, doneBy: 'Dad')!;
      final other = await AppState.loadForTesting(
        File('${dir.path}/other.json'),
      );
      others.add(other);
      void sync() {
        final collector = QrCollector();
        for (final code in app.qrCodesFor(null)) {
          collector.add(code);
        }
        other.receiveQr(collector.result());
      }

      sync();
      sync();
      expect(other.routineHistory().single.id, c.id);
      expect(other.counts['completion'], 1);
      app.setRoutineCompletionDeleted(c, true);
      sync();
      expect(other.routineHistory(), isEmpty);
      expect(other.counts['completion'], 0);
      app.setRoutineCompletionDeleted(c, false);
      sync();
      expect(other.routineHistory().single.doneBy, 'Dad');
    },
  );
}

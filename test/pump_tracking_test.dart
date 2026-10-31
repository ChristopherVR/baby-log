import 'package:baby_app/src/history_stats.dart';
import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/momcozy.dart';
import 'package:baby_app/src/pump_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 10, 31, 4);

PumpHistoryRecord rec(
  int minute,
  PumpEvent event,
  PumpRunState state, {
  int milk = 0,
}) => PumpHistoryRecord(
  time: _t0.add(Duration(minutes: minute)),
  eventCode: event.code,
  runStateCode: state.code,
  modeCode: 1,
  level: 4,
  battery: 90,
  milkMl: milk,
  vibration: 0,
  heating: 0,
  posture: 0,
);

PumpStatus status(PumpRunState state, int secs, {int milk = 0}) => PumpStatus(
  battery: 90,
  runStateCode: state.code,
  sideCode: 0,
  modeCode: 2,
  level: 4,
  frequency: 1,
  totalSeconds: secs,
  modeSeconds: secs,
  modeTotalSeconds: 0,
  milkMl: milk,
  errorCode: 0,
);

void main() {
  test('a session runs from the first pumping record to power off', () {
    final s = sessionsFromHistory([
      rec(0, PumpEvent.poweredOn, PumpRunState.stopped),
      rec(1, PumpEvent.powerKey, PumpRunState.running),
      rec(5, PumpEvent.modeKey, PumpRunState.running, milk: 40),
      rec(9, PumpEvent.powerKey, PumpRunState.stopped),
      rec(11, PumpEvent.powerKey, PumpRunState.running, milk: 70),
      rec(20, PumpEvent.poweredOff, PumpRunState.running),
    ], side: FeedSide.left);
    expect(s, hasLength(1));
    expect(s.single.time, _t0.add(const Duration(minutes: 1)).toLocal());
    expect(s.single.durationMin, 19);
    expect(s.single.amountMl, 70);
    expect(s.single.leftMl, 70);
    expect(s.single.side, FeedSide.left);
  });

  test('a long pause ends the session; quick presses are ignored', () {
    final s = sessionsFromHistory([
      rec(0, PumpEvent.powerKey, PumpRunState.running),
      rec(15, PumpEvent.powerKey, PumpRunState.stopped),
      rec(40, PumpEvent.powerKey, PumpRunState.running),
      rec(40, PumpEvent.poweredOff, PumpRunState.running),
    ], side: FeedSide.right);
    expect(s.map((e) => e.durationMin), [15]);
  });

  test('a session still running is left to the live view', () {
    final s = sessionsFromHistory([
      rec(0, PumpEvent.powerKey, PumpRunState.running),
      rec(8, PumpEvent.levelUp, PumpRunState.running),
    ], side: FeedSide.left);
    expect(s, isEmpty);
  });

  test('left and right sessions at the same time become one', () {
    final l = sessionsFromHistory([
      rec(0, PumpEvent.powerKey, PumpRunState.running, milk: 60),
      rec(20, PumpEvent.poweredOff, PumpRunState.running),
    ], side: FeedSide.left);
    final r = sessionsFromHistory([
      rec(1, PumpEvent.powerKey, PumpRunState.running, milk: 45),
      rec(18, PumpEvent.poweredOff, PumpRunState.running),
      rec(60, PumpEvent.powerKey, PumpRunState.running),
      rec(75, PumpEvent.poweredOff, PumpRunState.running),
    ], side: FeedSide.right);
    final m = mergeSides([...l, ...r]);
    expect(m, hasLength(2));
    expect(m.first.side, FeedSide.both);
    expect(m.first.durationMin, 20);
    expect((m.first.leftMl, m.first.rightMl, m.first.amountMl), (60, 45, 105));
    expect(m.last.side, FeedSide.right);
  });

  test('already logged sessions are recognised', () {
    final logged = [
      Entry(type: EntryType.pump, time: _t0.add(const Duration(minutes: 2))),
    ];
    final found = Entry(type: EntryType.pump, time: _t0);
    expect(alreadyLogged(found, logged), isTrue);
    expect(
      alreadyLogged(
        Entry(type: EntryType.pump, time: _t0.add(const Duration(hours: 1))),
        logged,
      ),
      isFalse,
    );
  });

  test('a live run ends when every pump that ran is off', () {
    final run = PumpRun();
    final now = DateTime(2026, 10, 31, 9);
    expect(
      run.update(FeedSide.left, status(PumpRunState.stopped, 0), now),
      isFalse,
    );
    expect(run.active, isFalse);
    run.update(FeedSide.left, status(PumpRunState.running, 30), now);
    run.update(FeedSide.right, status(PumpRunState.running, 25), now);
    expect(run.started, now.subtract(const Duration(seconds: 30)));
    final later = now.add(const Duration(minutes: 15));
    expect(
      run.update(FeedSide.left, status(PumpRunState.off, 930, milk: 50), later),
      isFalse,
    );
    expect(
      run.update(
        FeedSide.right,
        status(PumpRunState.off, 920, milk: 40),
        later,
      ),
      isTrue,
    );
    final d = run.draft(later);
    expect(d.side, FeedSide.both);
    expect(d.durationMin, 16);
    expect((d.leftMl, d.rightMl, d.amountMl), (50, 40, 90));
  });

  test('the clock stands still while the pumps are paused', () {
    final run = PumpRun();
    final t = DateTime(2026, 10, 31, 9);
    run.update(FeedSide.left, status(PumpRunState.running, 60), t);
    expect(
      run.pumped(t.add(const Duration(seconds: 3))),
      const Duration(seconds: 63),
    );
    run.update(
      FeedSide.left,
      status(PumpRunState.stopped, 65),
      t.add(const Duration(seconds: 5)),
    );
    expect(run.running, isFalse);
    expect(
      run.pumped(t.add(const Duration(minutes: 4))),
      const Duration(seconds: 65),
    );
  });

  test('history charts count pumping per day and per hour', () {
    final now = DateTime(2026, 10, 31, 18);
    final stats = HistoryStats(
      [
        Entry(
          type: EntryType.pump,
          time: DateTime(2026, 10, 31, 7, 10),
          durationMin: 18,
          amountMl: 120,
        ),
        Entry(
          type: EntryType.pump,
          time: DateTime(2026, 10, 30, 7, 40),
          durationMin: 15,
          amountMl: 90,
        ),
      ],
      now: now,
      days: 7,
    );
    expect(stats.hasPumping, isTrue);
    expect(stats.pumps.last, 1);
    expect(stats.pumpMl.sublist(5), [90, 120]);
    expect(stats.pumpMinutes.last, 18);
    expect(stats.pumpByHour[7], 2);
  });
}

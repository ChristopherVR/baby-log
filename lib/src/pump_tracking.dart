import 'models.dart';
import 'momcozy.dart';

/// A pause longer than this ends a session found in a pump's log.
const _longPause = Duration(minutes: 10);

/// Sessions shorter than this are taken as button fiddling.
const _shortest = Duration(minutes: 1);

/// Rebuilds pumping sessions from one pump's event log. Sessions still
/// running at the end of the log are left out: the live view covers them.
List<Entry> sessionsFromHistory(
  List<PumpHistoryRecord> records, {
  required FeedSide side,
}) {
  final sorted = [...records]..sort((a, b) => a.time.compareTo(b.time));
  final out = <Entry>[];
  DateTime? start;
  DateTime? pausedAt;
  var milk = 0;

  void close(DateTime end) {
    final s = start!;
    start = null;
    pausedAt = null;
    if (end.difference(s) < _shortest) return;
    out.add(
      Entry(
        type: EntryType.pump,
        time: s.toLocal(),
        endTime: end.toLocal(),
        side: side,
        durationMin: end.difference(s).inMinutes,
        amountMl: milk > 0 ? milk : null,
        leftMl: milk > 0 && side == FeedSide.left ? milk : null,
        rightMl: milk > 0 && side == FeedSide.right ? milk : null,
      ),
    );
  }

  for (final r in sorted) {
    if (start != null &&
        pausedAt != null &&
        r.time.difference(pausedAt!) > _longPause) {
      close(pausedAt!);
    }
    final running = r.runState == PumpRunState.running;
    if (start == null) {
      if (!running) continue;
      start = r.time;
      milk = 0;
    }
    if (r.milkMl > milk) milk = r.milkMl;
    switch (r.event) {
      case PumpEvent.poweredOff ||
          PumpEvent.lowBatteryOff ||
          PumpEvent.timeoutOff:
        close(r.time);
      default:
        if (r.runState == PumpRunState.off) {
          close(r.time);
        } else {
          pausedAt = running ? null : (pausedAt ?? r.time);
        }
    }
  }
  return out;
}

/// Joins a left and a right session that ran at the same time into one
/// session for both sides.
List<Entry> mergeSides(List<Entry> sessions) {
  const near = Duration(minutes: 3);
  final sorted = [...sessions]..sort((a, b) => a.time.compareTo(b.time));
  final out = <Entry>[];
  for (final s in sorted) {
    final i = out.lastIndexWhere(
      (o) =>
          o.side != s.side &&
          o.side != FeedSide.both &&
          s.time.difference(o.time).abs() <= near,
    );
    if (i < 0) {
      out.add(s);
      continue;
    }
    final o = out[i];
    final l = o.side == FeedSide.left ? o : s;
    final r = o.side == FeedSide.left ? s : o;
    final start = l.time.isBefore(r.time) ? l.time : r.time;
    final end = [
      l.endTime ?? l.time,
      r.endTime ?? r.time,
    ].reduce((a, b) => a.isAfter(b) ? a : b);
    final lm = l.leftMl, rm = r.rightMl;
    out[i] = Entry(
      type: EntryType.pump,
      time: start,
      endTime: end,
      side: FeedSide.both,
      durationMin: end.difference(start).inMinutes,
      amountMl: lm == null && rm == null ? null : (lm ?? 0) + (rm ?? 0),
      leftMl: lm,
      rightMl: rm,
    );
  }
  return out;
}

/// True if [found] looks like a session already in the log.
bool alreadyLogged(Entry found, Iterable<Entry> logged) => logged.any(
  (e) =>
      !e.deleted &&
      e.type == EntryType.pump &&
      e.time.difference(found.time).abs() <= const Duration(minutes: 5),
);

/// Follows a live session across one or two connected pumps.
class PumpRun {
  DateTime? started;
  final _last = <FeedSide, PumpStatus>{};
  final _lastAt = <FeedSide, DateTime>{};
  bool _ran = false;

  bool get active => started != null;

  /// Takes a status from the pump on [side]; returns true once every pump
  /// that ran has switched off, i.e. the session just ended.
  bool update(FeedSide side, PumpStatus s, DateTime now) {
    if (s.runState == PumpRunState.running) {
      started ??= now.subtract(Duration(seconds: s.totalSeconds));
      _ran = true;
    }
    if (started == null) return false;
    _last[side] = s;
    _lastAt[side] = now;
    return _ran && _last.values.every((x) => x.runState == PumpRunState.off);
  }

  bool get running =>
      _last.values.any((s) => s.runState == PumpRunState.running);

  /// Time spent pumping, by the pumps' own counters, which stand still
  /// while paused. Between updates it runs on only while a pump runs.
  Duration pumped(DateTime now) {
    var best = Duration.zero;
    for (final MapEntry(key: side, value: s) in _last.entries) {
      var d = Duration(seconds: s.totalSeconds);
      if (s.runState == PumpRunState.running) {
        final since = now.difference(_lastAt[side]!);
        if (since > Duration.zero && since < const Duration(seconds: 10)) {
          d += since;
        }
      }
      if (d > best) best = d;
    }
    return best;
  }

  /// The session so far, for the user to confirm.
  Entry draft(DateTime now) {
    final sides = _last.keys.toSet();
    final secs = _last.values.fold<int>(
      0,
      (m, s) => s.totalSeconds > m ? s.totalSeconds : m,
    );
    final mins = secs > 0
        ? (secs / 60).round()
        : now.difference(started ?? now).inMinutes;
    int? milk(FeedSide side) {
      final v = _last[side]?.milkMl ?? 0;
      return v > 0 ? v : null;
    }

    final l = milk(FeedSide.left), r = milk(FeedSide.right);
    return Entry(
      type: EntryType.pump,
      time: started ?? now,
      side: sides.length == 1 ? sides.first : FeedSide.both,
      durationMin: mins,
      amountMl: l == null && r == null ? null : (l ?? 0) + (r ?? 0),
      leftMl: sides.length > 1 ? l : null,
      rightMl: sides.length > 1 ? r : null,
    );
  }

  void reset() {
    started = null;
    _last.clear();
    _lastAt.clear();
    _ran = false;
  }
}

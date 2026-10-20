/// A local calendar range, optionally restricted to one hour of each day.
class HistoryPeriod {
  const HistoryPeriod({this.start, this.end, this.hour});

  final DateTime? start;
  final DateTime? end;
  final int? hour;

  static DateTime day(DateTime time) {
    final t = time.toLocal();
    return DateTime(t.year, t.month, t.day);
  }

  factory HistoryPeriod.recent(DateTime now, int days) {
    final today = day(now);
    return HistoryPeriod(
      start: DateTime(today.year, today.month, today.day - days + 1),
      end: today,
    );
  }

  bool contains(DateTime time) {
    final local = time.toLocal();
    final date = day(local);
    return (start == null || !date.isBefore(start!)) &&
        (end == null || !date.isAfter(end!)) &&
        (hour == null || local.hour == hour);
  }
}

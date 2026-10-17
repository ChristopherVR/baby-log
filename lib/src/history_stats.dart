import 'models.dart';

/// Calendar-day totals and local-hour frequencies for a rolling date range.
class HistoryStats {
  HistoryStats(
    Iterable<Entry> entries, {
    required DateTime now,
    required int days,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    dates = List.generate(
      days,
      (i) => DateTime(today.year, today.month, today.day - days + 1 + i),
    );
    pee = List.filled(days, 0);
    poo = List.filled(days, 0);
    sleepHours = List.filled(days, 0.0);
    final indexes = {for (var i = 0; i < dates.length; i++) dates[i]: i};
    for (final e in entries) {
      if (e.deleted || e.time.isAfter(now)) continue;
      final t = e.time.toLocal();
      final index = indexes[DateTime(t.year, t.month, t.day)];
      if (index != null) {
        if (e.type == EntryType.feed) feedByHour[t.hour]++;
        if (e.type == EntryType.nappy) {
          final kind = e.nappy ?? NappyKind.pee;
          if (kind != NappyKind.poo) {
            pee[index]++;
            peeByHour[t.hour]++;
          }
          if (kind != NappyKind.pee) {
            poo[index]++;
            pooByHour[t.hour]++;
          }
        }
      }
      if (e.type != EntryType.sleep) continue;
      final finish = e.endTime == null || e.endTime!.isAfter(now)
          ? now
          : e.endTime!;
      // Split overnight naps at local midnight; clip to the selected range.
      var cursor = t.isBefore(dates.first) ? dates.first : t;
      while (cursor.isBefore(finish)) {
        final day = DateTime(cursor.year, cursor.month, cursor.day);
        final next = DateTime(day.year, day.month, day.day + 1);
        final stop = finish.isBefore(next) ? finish : next;
        final i = indexes[day];
        if (i != null) {
          sleepHours[i] += stop.difference(cursor).inMilliseconds / 3600000;
        }
        cursor = stop;
      }
    }
  }

  late final List<DateTime> dates;
  late final List<int> pee;
  late final List<int> poo;
  late final List<double> sleepHours;
  final feedByHour = List.filled(24, 0);
  final peeByHour = List.filled(24, 0);
  final pooByHour = List.filled(24, 0);
}

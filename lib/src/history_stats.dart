import 'history_period.dart';
import 'models.dart';

/// Calendar totals and local-hour frequencies, clipped to an explicit period.
class HistoryStats {
  HistoryStats(
    Iterable<Entry> entries, {
    required DateTime now,
    required int days,
    HistoryPeriod? period,
  }) {
    final selected = period ?? HistoryPeriod.recent(now, days);
    final first = selected.start ?? HistoryPeriod.day(now);
    final last = selected.end ?? HistoryPeriod.day(now);
    dates = [];
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      dates.add(d);
    }
    final count = dates.length;
    feeds = List.filled(count, 0);
    feedMinutes = List.filled(count, 0);
    bottleMl = List.filled(count, 0);
    pills = List.filled(count, 0);
    pee = List.filled(count, 0);
    poo = List.filled(count, 0);
    sleepHours = List.filled(count, 0.0);
    loggedDays = List.filled(count, false);
    final indexes = {for (var i = 0; i < dates.length; i++) dates[i]: i};
    final rangeEnd = DateTime(last.year, last.month, last.day + 1);
    for (final e in entries) {
      if (e.deleted || e.time.isAfter(now)) continue;
      final t = e.time.toLocal();
      final index = indexes[HistoryPeriod.day(t)];
      if (index != null && selected.contains(t)) {
        loggedDays[index] = true;
        if (e.type == EntryType.feed) {
          feeds[index]++;
          feedMinutes[index] += e.durationMin ?? 0;
          bottleMl[index] += e.amountMl ?? 0;
          feedByHour[t.hour]++;
        }
        if (e.type == EntryType.pill) pills[index]++;
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
      var finish = e.endTime == null || e.endTime!.isAfter(now)
          ? now.toLocal()
          : e.endTime!.toLocal();
      if (finish.isAfter(rangeEnd)) finish = rangeEnd;
      // Split sleep at hour boundaries, including naps starting before the range.
      var cursor = t.isBefore(first) ? first : t;
      while (cursor.isBefore(finish)) {
        final next = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          cursor.hour + 1,
        );
        final stop = finish.isBefore(next) ? finish : next;
        final i = indexes[HistoryPeriod.day(cursor)];
        if (i != null &&
            (selected.hour == null || cursor.hour == selected.hour)) {
          final hours = stop.difference(cursor).inMilliseconds / 3600000;
          sleepHours[i] += hours;
          sleepByHour[cursor.hour] += hours;
          loggedDays[i] = true;
        }
        cursor = stop;
      }
    }
    final today = HistoryPeriod.day(now);
    completedIndexes = [
      for (var i = 0; i < count; i++)
        if (dates[i].isBefore(today)) i,
    ];
  }

  late final List<DateTime> dates;
  late final List<int> feeds;
  late final List<int> feedMinutes;
  late final List<int> bottleMl;
  late final List<int> pills;
  late final List<int> pee;
  late final List<int> poo;
  late final List<double> sleepHours;
  late final List<bool> loggedDays;
  late final List<int> completedIndexes;
  final feedByHour = List.filled(24, 0);
  final peeByHour = List.filled(24, 0);
  final pooByHour = List.filled(24, 0);
  final sleepByHour = List.filled(24, 0.0);

  bool get canEstimate =>
      completedIndexes.where((i) => loggedDays[i]).length >= 3;

  double estimate(List<num> values) => completedIndexes.isEmpty
      ? 0
      : completedIndexes.fold<double>(0, (sum, i) => sum + values[i]) /
            completedIndexes.length;
}

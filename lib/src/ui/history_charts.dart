import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../history_stats.dart';
import 'common.dart';
import 'theme.dart';

class HistoryCharts extends StatefulWidget {
  const HistoryCharts({super.key});

  @override
  State<HistoryCharts> createState() => _HistoryChartsState();
}

class _HistoryChartsState extends State<HistoryCharts> {
  int days = 7;

  @override
  Widget build(BuildContext context) {
    final stats = HistoryStats(
      AppScope.of(context).entries,
      now: DateTime.now(),
      days: days,
    );
    final dates = stats.dates.map(DateFormat('d MMM').format).toList();
    final hours = List.generate(
      24,
      (h) => DateFormat('ha').format(DateTime(2000, 1, 1, h)).toLowerCase(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const LText(
          'Discover daily patterns',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const LText(
          'Charts use all logs for this baby in the selected period. Mixed nappies count as both wee and poo.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final d in [7, 14, 30])
              ChoiceChip(
                label: LText('$d days'),
                selected: days == d,
                onSelected: (_) => setState(() => days = d),
              ),
          ],
        ),
        const SectionTitle('Daily totals'),
        _BarChart(
          title: 'Wees per day',
          values: stats.pee,
          labels: dates,
          color: Baby.pee,
        ),
        _BarChart(
          title: 'Poos per day',
          values: stats.poo,
          labels: dates,
          color: Baby.poo,
        ),
        _BarChart(
          title: 'Sleep hours per day',
          values: stats.sleepHours,
          labels: dates,
          color: Baby.pill,
          hours: true,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LText(
            'Sleep is split at midnight. An ongoing nap is included up to now.',
          ),
        ),
        const SectionTitle('Patterns by hour'),
        const LText(
          'Total logs in each hour across the selected days. Tap a bar for its exact count; swipe to see all hours.',
        ),
        const SizedBox(height: 12),
        _BarChart(
          title: 'Feeds by hour',
          values: stats.feedByHour,
          labels: hours,
          color: Baby.feed,
          hourly: true,
        ),
        _BarChart(
          title: 'Poos by hour',
          values: stats.pooByHour,
          labels: hours,
          color: Baby.poo,
          hourly: true,
        ),
        _BarChart(
          title: 'Wees by hour',
          values: stats.peeByHour,
          labels: hours,
          color: Baby.pee,
          hourly: true,
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.title,
    required this.values,
    required this.labels,
    required this.color,
    this.hours = false,
    this.hourly = false,
  });
  final String title;
  final List<num> values;
  final List<String> labels;
  final Color color;
  final bool hours;
  final bool hourly;

  String amount(num value) =>
      hours ? '${value.toStringAsFixed(1)} h' : '${value.toInt()}';

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<num>(0, math.max);
    final scale = math.max(1, peak.ceil());
    final total = values.fold<num>(0, (a, b) => a + b);
    final peaks = [
      for (var i = 0; i < values.length; i++)
        if (values[i] == peak) labels[i],
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                ),
                LText(
                  amount(total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LText(
              peak == 0
                  ? 'No logs in this period'
                  : hourly
                  ? '${tr('Most logged')}: ${peaks.join(', ')}'
                  : '${tr('Highest day')}: ${amount(peak)}',
              style: TextStyle(color: Baby.muted),
            ),
            const SizedBox(height: 16),
            LText(
              '${tr('Scale')}: 0 – ${amount(scale)}',
              style: TextStyle(fontSize: 12, color: Baby.muted),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  values.length * 44.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: Tooltip(
                              triggerMode: TooltipTriggerMode.tap,
                              message: '${labels[i]}: ${amount(values[i])}',
                              child: Semantics(
                                label:
                                    '${tr(title)}, ${labels[i]}: ${amount(values[i])}',
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 120,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: 22,
                                          height: values[i] == 0
                                              ? 2
                                              : 120 * values[i] / scale,
                                          decoration: BoxDecoration(
                                            color: values[i] == 0
                                                ? Baby.line
                                                : color,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(5),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 24,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            labels[i],
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Baby.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

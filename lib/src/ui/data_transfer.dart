import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import 'common.dart';

String _stamp() => DateFormat('yyyy-MM-dd').format(DateTime.now());

Future<void> _save(
  BuildContext context,
  String fileName,
  String text,
  String mimeType,
) async {
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: mimeType,
    );
    if (uri != null && context.mounted) showMessage(context, 'Saved $fileName');
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not save: $e');
  }
}

/// Full backup of everything, which can be imported again later.
Future<void> exportBackupFile(BuildContext context) => _save(
  context,
  'baby-log-backup-${_stamp()}.json',
  AppScope.of(context).exportBackup(),
  'application/json',
);

/// The given entries as a spreadsheet (CSV).
Future<void> exportCsvFile(BuildContext context, List<Entry> entries) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final rows = [
    [
      'Date',
      'Time',
      'Type',
      'What',
      'Duration (min)',
      'Amount (ml)',
      'Sleep end',
    ],
    for (final e in entries)
      [
        DateFormat('yyyy-MM-dd').format(e.time),
        hm(e.time),
        switch (e.type) {
          EntryType.feed => 'Feed',
          EntryType.nappy => 'Nappy',
          EntryType.pill => 'Pill',
          EntryType.sleep => 'Sleep',
          EntryType.pump => 'Pump',
        },
        switch (e.type) {
          EntryType.feed => e.side == null ? 'Breast' : sideLabel(e.side!),
          EntryType.nappy => nappyLabel(e.nappy ?? NappyKind.pee),
          EntryType.pill => e.medName ?? '',
          EntryType.sleep => e.endTime == null ? 'Sleeping' : 'Nap',
          EntryType.pump => e.side == null ? '' : sideLabel(e.side!),
        },
        e.type == EntryType.sleep
            ? e.endTime?.difference(e.time).inMinutes
            : e.durationMin,
        e.amountMl,
        e.endTime?.toIso8601String(),
      ],
  ];
  final csv = rows.map((r) => r.map(cell).join(',')).join('\r\n');
  return _save(context, 'baby-log-${_stamp()}.csv', csv, 'text/csv');
}

/// Picks a backup file and merges it into the log.
Future<void> importBackupFile(BuildContext context) async {
  final app = AppScope.of(context);
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Nestling backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;
    final result = app.importBackup(utf8.decode(await file.readAsBytes()));
    if (!context.mounted) return;
    showMessage(
      context,
      result.entries +
                  result.meds +
                  result.babies +
                  result.routines +
                  result.completions +
                  result.growth ==
              0
          ? 'Nothing new in that backup'
          : 'Imported ${result.entries} entries, ${result.meds} pills, ${result.babies} profiles and ${result.routines} routines and ${result.completions} completions, ${result.growth} growth entries',
    );
  } on FormatException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not import: $e');
  }
}

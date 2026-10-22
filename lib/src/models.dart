import 'dart:convert';
import 'dart:math';

enum EntryType { feed, nappy, pill, sleep }

enum FeedSide { left, right, both, bottle }

enum NappyKind { pee, poo, both }

enum ScheduleMode { timesPerDay, everyHours }

String newId() {
  final r = Random.secure();
  return List.generate(
    12,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

T? _enum<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

DateTime _ms(Object? v) =>
    DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);

/// Anything that is shared between devices. Merging keeps the copy with the
/// newest [updatedAt]; deletes are kept as tombstones so they sync too.
abstract class Syncable {
  String get id;
  DateTime get updatedAt;
  bool get deleted;
  Map<String, dynamic> toJson();
}

class Entry implements Syncable {
  final String? babyId;
  @override
  final String id;
  final EntryType type;
  final DateTime time;
  final DateTime? endTime;
  final FeedSide? side;
  final int? durationMin;
  final int? amountMl;
  final NappyKind? nappy;
  final String? medId;
  final String? medName;

  /// Name and id of the device that logged it.
  final String? by;
  final String? byId;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Entry({
    this.babyId,
    String? id,
    required this.type,
    required this.time,
    this.endTime,
    this.side,
    this.durationMin,
    this.amountMl,
    this.nappy,
    this.medId,
    this.medName,
    this.by,
    this.byId,
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The same entry with a new edit time, who logged it, or deleted state.
  Entry copyWith({
    required DateTime updatedAt,
    String? by,
    String? byId,
    bool? deleted,
    String? babyId,
  }) => Entry(
    babyId: babyId ?? this.babyId,
    id: id,
    type: type,
    time: time,
    endTime: endTime,
    side: side,
    durationMin: durationMin,
    amountMl: amountMl,
    nappy: nappy,
    medId: medId,
    medName: medName,
    by: by ?? this.by,
    byId: byId ?? this.byId,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
  );

  @override
  Map<String, dynamic> toJson() => {
    if (babyId != null) 'babyId': babyId,
    'id': id,
    'type': type.name,
    'time': time.millisecondsSinceEpoch,
    if (endTime != null) 'endTime': endTime!.millisecondsSinceEpoch,
    if (side != null) 'side': side!.name,
    if (durationMin != null) 'durationMin': durationMin,
    if (amountMl != null) 'amountMl': amountMl,
    if (nappy != null) 'nappy': nappy!.name,
    if (medId != null) 'medId': medId,
    if (medName != null) 'medName': medName,
    if (by != null) 'by': by,
    if (byId != null) 'byId': byId,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    if (deleted) 'deleted': true,
  };

  static Entry? fromJson(Map<String, dynamic> j) {
    final type = _enum(EntryType.values, j['type']);
    if (type == null || j['id'] is! String) return null;
    return Entry(
      babyId: j['babyId'] as String?,
      id: j['id'],
      type: type,
      time: _ms(j['time']),
      endTime: j['endTime'] == null ? null : _ms(j['endTime']),
      side: _enum(FeedSide.values, j['side']),
      durationMin: (j['durationMin'] as num?)?.toInt(),
      amountMl: (j['amountMl'] as num?)?.toInt(),
      nappy: _enum(NappyKind.values, j['nappy']),
      medId: j['medId'] as String?,
      medName: j['medName'] as String?,
      by: j['by'] as String?,
      byId: j['byId'] as String?,
      updatedAt: _ms(j['updatedAt']),
      deleted: j['deleted'] == true,
    );
  }
}

class Medication implements Syncable {
  @override
  final String id;
  final String name;
  final String dose;
  final ScheduleMode mode;

  /// Times per day, or hours between doses, depending on [mode].
  final int count;

  /// First dose of the day, in minutes after midnight.
  final int startMinutes;

  /// Default for reminders on the device that added it ([createdBy]); other
  /// devices only remind if switched on there.
  final bool remind;

  /// Device id of the phone that added it.
  final String? createdBy;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Medication({
    String? id,
    required this.name,
    this.dose = '',
    this.mode = ScheduleMode.timesPerDay,
    this.count = 2,
    this.startMinutes = 8 * 60,
    this.remind = true,
    this.createdBy,
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now();

  int get intervalMinutes =>
      mode == ScheduleMode.timesPerDay ? (24 * 60 / count).round() : count * 60;

  /// Dose times for a day (minutes after midnight), sorted. The schedule
  /// restarts every day at [startMinutes].
  List<int> get slots {
    final out = <int>{};
    for (var m = 0; m < 24 * 60; m += intervalMinutes) {
      out.add((startMinutes + m) % (24 * 60));
    }
    return out.toList()..sort();
  }

  String get scheduleLabel => mode == ScheduleMode.timesPerDay
      ? '$count× a day'
      : 'Every $count hour${count == 1 ? '' : 's'}';

  Medication copyWith({
    String? name,
    String? dose,
    ScheduleMode? mode,
    int? count,
    int? startMinutes,
    bool? remind,
    String? createdBy,
    DateTime? updatedAt,
    bool? deleted,
  }) => Medication(
    id: id,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    mode: mode ?? this.mode,
    count: count ?? this.count,
    startMinutes: startMinutes ?? this.startMinutes,
    remind: remind ?? this.remind,
    createdBy: createdBy ?? this.createdBy,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'mode': mode.name,
    'count': count,
    'startMinutes': startMinutes,
    'remind': remind,
    if (createdBy != null) 'createdBy': createdBy,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    if (deleted) 'deleted': true,
  };

  static Medication? fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String) return null;
    return Medication(
      id: j['id'],
      name: j['name'] as String? ?? '',
      dose: j['dose'] as String? ?? '',
      mode: _enum(ScheduleMode.values, j['mode']) ?? ScheduleMode.timesPerDay,
      count: ((j['count'] as num?)?.toInt() ?? 2).clamp(1, 24),
      startMinutes: (j['startMinutes'] as num?)?.toInt() ?? 8 * 60,
      remind: j['remind'] != false,
      createdBy: j['createdBy'] as String?,
      updatedAt: _ms(j['updatedAt']),
      deleted: j['deleted'] == true,
    );
  }
}

/// What one sync with a paired device moved, for the device's detail page.
class SyncRecord {
  final DateTime at;

  /// True if this phone started the sync, false if the other phone did.
  final bool outgoing;

  /// Records sent / received in total, and how many of them were new or newer.
  final int sent;
  final int received;
  final int newThere;
  final Map<String, int> newHere;
  final int bytes;

  SyncRecord({
    required this.at,
    required this.outgoing,
    required this.sent,
    required this.received,
    required this.newThere,
    required this.newHere,
    required this.bytes,
  });

  int get newHereTotal => newHere.values.fold(0, (a, b) => a + b);
  bool get changedSomething => newThere > 0 || newHereTotal > 0;

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'outgoing': outgoing,
    'sent': sent,
    'received': received,
    'newThere': newThere,
    'newHere': newHere,
    'bytes': bytes,
  };

  static SyncRecord fromJson(Map<String, dynamic> j) => SyncRecord(
    at: _ms(j['at']),
    outgoing: j['outgoing'] == true,
    sent: (j['sent'] as num?)?.toInt() ?? 0,
    received: (j['received'] as num?)?.toInt() ?? 0,
    newThere: (j['newThere'] as num?)?.toInt() ?? 0,
    newHere: {
      for (final e in Map<String, dynamic>.from(
        j['newHere'] as Map? ?? {},
      ).entries)
        e.key: (e.value as num).toInt(),
    },
    bytes: (j['bytes'] as num?)?.toInt() ?? 0,
  );
}

/// Another member of the sharing hub (paired directly or learned from a member).
class Peer {
  final String deviceId;
  String host;
  int port;
  String key;
  String name;
  DateTime? lastSync;
  String? lastError;

  /// The other phone's app version, as last seen ('older' if it is too old to say).
  String? appVersion;

  /// A different version the user chose to sync with anyway.
  String? acceptedVersion;

  /// Set while syncing is paused because the versions differ.
  String? blockedVersion;

  /// The user chose to pause syncing with a different version; the other
  /// phone accepting it does not override this.
  bool pausedByUser = false;

  /// The other phone's counts per kind of record, from its last answer.
  Map<String, int> remoteCounts = {};

  /// Our change counter value the other phone has confirmed receiving, and
  /// its counter value we have received up to. Syncs send only what is newer.
  int ackedSeq = 0;
  int theirSeq = 0;

  SyncRecord? last;

  /// Learned from another member of the hub rather than paired directly.
  bool learnedFromHub = false;

  /// Consecutive failed syncs, and whether the last failure was "cannot reach".
  /// Not saved: they only describe the current session.
  int failures = 0;
  bool unreachable = false;

  /// Known through the hub but never reached yet.
  bool get neverReached => learnedFromHub && lastSync == null;

  /// Recent syncs that changed something, newest first.
  List<SyncRecord> history = [];

  Peer({
    required this.deviceId,
    required this.host,
    required this.port,
    required this.key,
    this.name = '',
    this.lastSync,
  });

  void record(SyncRecord r) {
    last = r;
    lastSync = r.at;
    lastError = null;
    failures = 0;
    unreachable = false;
    if (r.changedSomething) {
      history.insert(0, r);
      if (history.length > 30) history.removeLast();
    }
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'host': host,
    'port': port,
    'key': key,
    'name': name,
    if (lastSync != null) 'lastSync': lastSync!.millisecondsSinceEpoch,
    if (appVersion != null) 'appVersion': appVersion,
    if (acceptedVersion != null) 'acceptedVersion': acceptedVersion,
    if (blockedVersion != null) 'blockedVersion': blockedVersion,
    if (pausedByUser) 'pausedByUser': true,
    if (learnedFromHub) 'learnedFromHub': true,
    'remoteCounts': remoteCounts,
    'ackedSeq': ackedSeq,
    'theirSeq': theirSeq,
    if (last != null) 'last': last!.toJson(),
    'history': [for (final r in history) r.toJson()],
  };

  static Peer fromJson(Map<String, dynamic> j) =>
      Peer(
          deviceId: j['deviceId'] as String,
          host: j['host'] as String,
          port: (j['port'] as num).toInt(),
          key: j['key'] as String,
          name: j['name'] as String? ?? '',
          lastSync: j['lastSync'] == null ? null : _ms(j['lastSync']),
        )
        ..appVersion = j['appVersion'] as String?
        ..acceptedVersion = j['acceptedVersion'] as String?
        ..blockedVersion = j['blockedVersion'] as String?
        ..pausedByUser = j['pausedByUser'] == true
        ..learnedFromHub = j['learnedFromHub'] == true
        ..remoteCounts = {
          for (final e in Map<String, dynamic>.from(
            j['remoteCounts'] as Map? ?? {},
          ).entries)
            e.key: (e.value as num).toInt(),
        }
        ..ackedSeq = (j['ackedSeq'] as num?)?.toInt() ?? 0
        ..theirSeq = (j['theirSeq'] as num?)?.toInt() ?? 0
        ..last = j['last'] == null
            ? null
            : SyncRecord.fromJson(Map<String, dynamic>.from(j['last']))
        ..history = [
          for (final r in j['history'] as List? ?? [])
            SyncRecord.fromJson(Map<String, dynamic>.from(r)),
        ];

  /// What other members need to reach this device (never our own entry).
  Map<String, dynamic> toMemberJson() => {
    'deviceId': deviceId,
    'name': name,
    'host': host,
    'port': port,
    'key': key,
  };
}

/// True if [a] should replace [b]: it is newer, or exactly as new but
/// different, in which case both phones pick the same one.
bool _wins(Syncable a, Syncable b) {
  final c = a.updatedAt.compareTo(b.updatedAt);
  if (c != 0) return c > 0;
  return jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson())) > 0;
}

/// Merges [incoming] into [current] (by id, newest wins) and returns the
/// records that were new or newer.
List<T> mergeChanged<T extends Syncable>(
  Map<String, T> current,
  Iterable<T> incoming,
) {
  final changed = <T>[];
  for (final item in incoming) {
    final existing = current[item.id];
    if (existing == null || _wins(item, existing)) {
      current[item.id] = item;
      changed.add(item);
    }
  }
  return changed;
}

/// Like [mergeChanged]; returns true if anything changed.
bool mergeInto<T extends Syncable>(
  Map<String, T> current,
  Iterable<T> incoming,
) => mergeChanged(current, incoming).isNotEmpty;

/// Short name for the kind of a shared record: feed, nappy, pill (a dose) or med (a pill schedule).
String kindOf(Syncable s) => s is Entry ? s.type.name : 'med';

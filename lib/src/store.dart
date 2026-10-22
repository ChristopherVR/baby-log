import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'background.dart';
import 'models.dart';
import 'growth.dart';
import 'routines.dart';
import 'localization.dart';
import 'notifications.dart';
import 'qr_transfer.dart';
import 'sync.dart';

/// All app data and actions. The UI listens to this and rebuilds on change.
class AppState extends ChangeNotifier {
  AppState._(this._file, [this._persist = true]);

  final bool _persist;

  /// Loads storage without starting platform services, for isolated tests.
  @visibleForTesting
  static Future<AppState> loadForTesting(
    File file, {
    bool persist = true,
  }) async {
    final state = AppState._(file, persist);
    await state._read();
    AppLanguage.use(state.language);
    state._rebuild();
    return state;
  }

  @visibleForTesting
  Future<void> get pendingSave => _saving;

  /// Starts the sync server (several states can run in one test).
  @visibleForTesting
  Future<void> startServerForTesting() =>
      server.start(
        onInfo: _handleInfo,
        onSync: _handleIncoming,
        anyPort: true,
      );

  final File _file;
  final reminders = Reminders();
  final server = SyncServer();

  /// This app's version (e.g. 1.1.0). Paired phones must match, or the user
  /// has to accept the difference.
  static String appVersion = '';

  /// Major.minor of a version ('1.2.3' -> '1.2'). Bug-fix releases (the third
  /// number) sync with each other freely; a different feature level needs the
  /// user to accept it.
  static String featureLevel(String? v) =>
      v == null ? '' : v.split('.').take(2).join('.');

  static bool sameFeatures(String? v) =>
      featureLevel(v) == featureLevel(appVersion);

  static bool _accepted(String? accepted, String theirs) =>
      accepted != null && featureLevel(accepted) == featureLevel(theirs);

  String deviceId = newId();
  String syncKey = _newKey();
  String deviceName = Platform.isAndroid ? 'Phone' : Platform.localHostname;

  /// True once the user typed their own device name. Until then the name is
  /// read from the device itself (e.g. "Galaxy S23") each time the app starts.
  bool deviceNameCustom = false;
  final Map<String, Entry> _entries = {};
  final Map<String, Medication> _meds = {};
  final Map<String, BabyProfile> _babies = {};
  final Map<String, GrowthEntry> _growth = {};
  final Map<String, Routine> _routines = {};
  final Map<String, RoutineCompletion> _routineCompletions = {};
  String caregiverName = '';
  String language = 'en';

  // Device-local acknowledgement; never synced or exported in a backup.
  String changelogSeenVersion = '';

  Future<void> acknowledgeChangelog(String version) {
    changelogSeenVersion = version;
    _save();
    return _saving;
  }

  void setLanguage(String value) {
    if (value != 'en' && value != 'af') return;
    language = value;
    AppLanguage.use(value);
    _settingsChanged();
  }

  final Map<String, bool> _routineRemindHere = {};
  String activeBabyId = defaultBabyId;
  final List<Peer> peers = [];

  /// Change counter: every record gets the next number when it changes here
  /// (locally or from a sync), so a sync only has to send what changed since
  /// the other phone last confirmed. [_from] remembers which paired device a
  /// record's current version came from, so it is not echoed straight back.
  int _seq = 0;
  final Map<String, int> _seqOf = {};
  final Map<String, String> _from = {};

  String _legacyBabyName = '';
  String get babyName => _babies[activeBabyId]?.name ?? _legacyBabyName;

  List<BabyProfile> get babies =>
      _babies.values.where((b) => !b.deleted).toList()..sort(
        (a, b) => a.id == b.id
            ? 0
            : a.id == defaultBabyId
            ? -1
            : b.id == defaultBabyId
            ? 1
            : a.name.compareTo(b.name),
      );
  List<Routine> get routines =>
      _routines.values
          .where((r) => !r.deleted && r.babyId == activeBabyId)
          .toList()
        ..sort((a, b) => a.minutes.compareTo(b.minutes));

  bool selectBaby(String id) {
    if (id == activeBabyId) return true;
    if (timerStart != null ||
        !_babies.containsKey(id) ||
        _babies[id]!.deleted) {
      return false;
    }
    activeBabyId = id;
    _changed(shared: false);
    return true;
  }

  /// Adds a baby and returns its id (null if the name is empty). By default the
  /// new baby becomes the selected one; pass [select] false to keep the current.
  String? addBaby(String name, {DateTime? dateOfBirth, bool select = true}) {
    if (name.trim().isEmpty) return null;
    final baby = BabyProfile(name: name.trim(), dateOfBirth: dateOfBirth);
    _babies[baby.id] = baby;
    _touch(baby.id);
    if (select && timerStart == null) activeBabyId = baby.id;
    _changed();
    return baby.id;
  }

  List<GrowthEntry> growthEntriesFor(String babyId) =>
      _growth.values.where((e) => !e.deleted && e.babyId == babyId).toList();

  BabyProfile get activeBaby => _babies[activeBabyId]!;

  List<GrowthEntry> get growthEntries =>
      _growth.values
          .where((e) => !e.deleted && e.babyId == activeBabyId)
          .toList()
        ..sort((a, b) {
          final day = b.date.compareTo(a.date);
          return day != 0 ? day : b.updatedAt.compareTo(a.updatedAt);
        });

  bool saveGrowth(GrowthEntry entry) {
    final baby = _babies[entry.babyId];
    final now = DateTime.now();
    if (baby == null ||
        baby.deleted ||
        entry.date.isAfter(DateTime(now.year, now.month, now.day)) ||
        (baby.dateOfBirth != null && entry.date.isBefore(baby.dateOfBirth!)) ||
        !validMeasurement(entry.weightKg) ||
        !validMeasurement(entry.heightCm) ||
        (entry.weightKg == null &&
            entry.heightCm == null &&
            entry.photo == null &&
            entry.note.trim().isEmpty)) {
      return false;
    }
    _growth[entry.id] = entry.copyWith(updatedAt: _editTime(_growth[entry.id]));
    _touch(entry.id);
    _changed();
    return true;
  }

  void setGrowthDeleted(GrowthEntry entry, bool deleted) {
    final current = _growth[entry.id];
    if (current == null) return;
    _growth[entry.id] = current.copyWith(
      updatedAt: _editTime(current),
      deleted: deleted,
    );
    _touch(entry.id);
    _changed();
  }

  void saveBabyProfile({
    required String name,
    DateTime? dateOfBirth,
    String? photo,
    String? id,
  }) {
    final existing = id == null ? activeBaby : (_babies[id] ?? activeBaby);
    _babies[existing.id] = BabyProfile(
      id: existing.id,
      name: name.trim(),
      dateOfBirth: dateOfBirth,
      photo: photo,
      updatedAt: _editTime(existing),
    );
    _touch(existing.id);
    _changed();
  }

  bool routineRemindsHere(Routine r) => _routineRemindHere[r.id] ?? false;

  List<RoutineCompletion> routineHistory({String? routineId, String? babyId}) =>
      _routineCompletions.values
          .where(
            (c) =>
                !c.deleted &&
                c.babyId == (babyId ?? activeBabyId) &&
                (routineId == null || c.routineId == routineId),
          )
          .toList()
        ..sort((a, b) {
          final order = b.time.compareTo(a.time);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });

  RoutineCompletion? lastRoutineCompletion(Routine r) =>
      routineHistory(routineId: r.id, babyId: r.babyId).firstOrNull;

  DateTime? nextRoutineAt(Routine r, DateTime now) {
    final last = lastRoutineCompletion(r);
    final doneToday =
        last != null &&
        last.time.year == now.year &&
        last.time.month == now.month &&
        last.time.day == now.day;
    return r.nextAt(
      doneToday ? DateTime(now.year, now.month, now.day + 1) : now,
    );
  }

  RoutineCompletion? completeRoutine(
    Routine routine, {
    required String doneBy,
    DateTime? time,
  }) {
    final current = _routines[routine.id];
    final at = time ?? DateTime.now();
    if (current == null ||
        current.deleted ||
        doneBy.trim().isEmpty ||
        at.isAfter(DateTime.now())) {
      return null;
    }
    final completion = RoutineCompletion(
      babyId: current.babyId,
      routineId: current.id,
      routineName: current.name,
      time: at,
      doneBy: doneBy.trim(),
      deviceId: deviceId,
    );
    caregiverName = doneBy.trim();
    _routineCompletions[completion.id] = completion;
    _touch(completion.id);
    _changed();
    return completion;
  }

  void setRoutineCompletionDeleted(RoutineCompletion completion, bool deleted) {
    final current = _routineCompletions[completion.id];
    if (current == null) return;
    _routineCompletions[completion.id] = current.copyWith(
      updatedAt: _editTime(current),
      deleted: deleted,
    );
    _touch(completion.id);
    _changed();
  }

  void saveRoutine(Routine routine, {bool? remind}) {
    if (routine.name.trim().isEmpty ||
        routine.weekdays.isEmpty ||
        routine.minutes < 0 ||
        routine.minutes >= 1440 ||
        routine.weekdays.any((d) => d < 1 || d > 7) ||
        !_babies.containsKey(routine.babyId)) {
      return;
    }
    _routines[routine.id] = routine.copyWith(
      updatedAt: _editTime(_routines[routine.id]),
    );
    if (remind != null) {
      _routineRemindHere[routine.id] = remind;
      if (remind) unawaited(reminders.requestPermission());
    }
    _touch(routine.id);
    _changed();
  }

  /// 'light', 'dark' or 'system'.
  String appearance = 'light';

  /// Night light: a dimmer, warmer light palette from 6 pm to 6 am.
  bool nightLight = true;

  /// False until the first-time setup has been finished or skipped.
  bool setupDone = false;
  final Map<String, bool> _feedReminderOn = {};
  final Map<String, int> _feedReminderMinutes = {};
  bool get feedReminderOn => _feedReminderOn[activeBabyId] ?? false;
  set feedReminderOn(bool on) => _feedReminderOn[activeBabyId] = on;
  int get feedReminderMinutes => _feedReminderMinutes[activeBabyId] ?? 180;
  set feedReminderMinutes(int minutes) =>
      _feedReminderMinutes[activeBabyId] = minutes;

  /// Ring reminders as alarms (alarm sound until stopped, full screen) instead
  /// of normal notifications. Per phone.
  bool feedAlarm = false;
  bool pillAlarm = false;
  bool autoSync = true;

  /// Pill reminders switched on or off on this phone (pill id -> on).
  final Map<String, bool> _remindHere = {};

  /// Per-dose reminder overrides on this phone ("medId:minutes" -> style).
  final Map<String, String> _pillReminderOverrides = {};

  /// Android: keep syncing while the app is closed (foreground service).
  bool backgroundSync = true;
  bool batteryExempt = true;

  /// Feed timer (local to this device only).
  FeedSide? timerSide;
  DateTime? timerStart;
  DateTime? timerPausedAt;
  int timerPausedMilliseconds = 0;
  bool timerReminders = true;
  bool get timerPaused => timerStart != null && timerPausedAt != null;

  Duration feedElapsed([DateTime? now]) {
    if (timerStart == null) return Duration.zero;
    return Duration(
      milliseconds: max(
        0,
        (timerPausedAt ?? now ?? DateTime.now())
                .difference(timerStart!)
                .inMilliseconds -
            timerPausedMilliseconds,
      ),
    );
  }

  /// The equivalent start with burping breaks removed. Stable between edits.
  DateTime? get timerActiveOrigin =>
      timerStart == null || timerPaused || !timerReminders
      ? null
      : timerStart!.add(Duration(milliseconds: timerPausedMilliseconds));

  bool syncing = false;
  List<String> ips = [];

  /// Set if the data file could not be read; holds the path of the kept copy.
  String? loadProblem;

  /// Started by Android's sync service without a screen.
  bool startedHeadless = false;

  List<Entry> _visible = [];
  List<Medication> _visibleMeds = [];
  Map<String, List<Entry>> _dosesByMed = {};
  Set<String> _possibleDuplicates = {};
  Future<void> _saving = Future.value();
  Timer? _syncDebounce;
  Timer? _syncPeriodic;
  Timer? _metaSave;

  /// A paired device was added or its address or code changed: save right away.
  bool _peersDirty = false;

  /// Devices removed from the hub on this device. Gossip from other members
  /// does not bring them back; pairing with one again explicitly does.
  final Set<String> _removedPeers = {};

  static String _newKey() =>
      (Random.secure().nextInt(900000) + 100000).toString();

  static Future<AppState> load({
    String profile = '',
    bool foreground = true,
  }) async {
    appVersion = (await PackageInfo.fromPlatform()).version;
    final dir = await getApplicationSupportDirectory();
    final name = profile.isEmpty ? 'babylog.json' : 'babylog_$profile.json';
    final state = AppState._(File('${dir.path}${Platform.pathSeparator}$name'));
    final hadIds = await state._read();
    AppLanguage.use(state.language);
    state._rebuild();
    final ownName = state.deviceNameCustom ? null : await DeviceIdentity.name();
    final renamed = ownName != null && ownName != state.deviceName;
    if (renamed) state.deviceName = ownName;
    // Persist a newly made device id and sync code straight away.
    if (!hadIds || renamed) state._save();
    await state.reminders.init();
    if (state.setupDone) unawaited(state.reminders.requestPermission());
    state._rescheduleReminders();
    await state.server.start(
      onInfo: state._handleInfo,
      onSync: state._handleIncoming,
    );
    await state.refreshIps();
    state._applyBackground();
    state.startedHeadless = !foreground;
    if (foreground) state.appResumed();
    return state;
  }

  String get dataFilePath => _file.path;

  // ---------------------------------------------------------------- app lifecycle

  /// While the app is on screen, check every 2 minutes for the other phone's
  /// changes. In the background there is no timer: local changes are pushed
  /// right away and the other phone's changes arrive by themselves.
  void appResumed() {
    startedHeadless = false;
    _rescheduleReminders();
    _syncPeriodic ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => syncAll(quiet: true),
    );
    unawaited(refreshIps());
    unawaited(syncAll(quiet: true));
  }

  void appPaused() {
    _syncPeriodic?.cancel();
    _syncPeriodic = null;
    flush();
  }

  /// Writes any pending sync details (last sync times etc.) to disk.
  void flush() {
    if (_metaSave == null) return;
    _metaSave!.cancel();
    _metaSave = null;
    _save();
  }

  // ---------------------------------------------------------------- reading

  List<Entry> get entries => _visible;
  List<Medication> get meds => _visibleMeds;

  Entry? _last(EntryType type) {
    for (final e in _visible) {
      if (e.type == type) return e;
    }
    return null;
  }

  Entry? get activeSleep => entries
      .where((e) => e.type == EntryType.sleep && e.endTime == null)
      .firstOrNull;

  bool startSleep({DateTime? time}) {
    final start = time ?? DateTime.now();
    if (activeSleep != null || start.isAfter(DateTime.now())) return false;
    addEntry(Entry(type: EntryType.sleep, time: start));
    return true;
  }

  bool endSleep(Entry sleep, {DateTime? time}) {
    final current = _entries[sleep.id];
    final end = time ?? DateTime.now();
    if (current == null ||
        current.deleted ||
        current.type != EntryType.sleep ||
        current.endTime != null ||
        end.isBefore(current.time) ||
        end.isAfter(DateTime.now())) {
      return false;
    }
    addEntry(
      Entry(
        id: current.id,
        babyId: current.babyId,
        type: EntryType.sleep,
        time: current.time,
        endTime: end,
      ),
    );
    return true;
  }

  Entry? get lastFeed => _last(EntryType.feed);
  Entry? get lastNappy => _last(EntryType.nappy);

  /// The breast to offer next: the opposite of the last single-side feed.
  FeedSide? get suggestedSide {
    for (final e in _visible) {
      if (e.type != EntryType.feed) continue;
      if (e.side == FeedSide.left) return FeedSide.right;
      if (e.side == FeedSide.right) return FeedSide.left;
    }
    return null;
  }

  DateTime? get feedReminderAt {
    final last = lastFeed;
    if (!feedReminderOn || last == null) return null;
    return last.time.add(Duration(minutes: feedReminderMinutes));
  }

  /// True if [e] looks like the same event logged on another phone too.
  bool isPossibleDuplicate(Entry e) => _possibleDuplicates.contains(e.id);

  /// Who logged [e], if it was another phone.
  String? loggedElsewhere(Entry e) {
    if (e.byId != null) {
      return e.byId == deviceId ? null : e.by ?? 'the other phone';
    }
    return e.by == null || e.by == deviceName ? null : e.by;
  }

  /// Entries on [day]. The list is newest first, so this stops at the first
  /// entry before that day instead of scanning everything.
  List<Entry> entriesOn(DateTime day, [EntryType? type]) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final out = <Entry>[];
    for (final e in _visible) {
      if (!e.time.isBefore(end)) continue;
      if (e.time.isBefore(start)) break;
      if (type == null || e.type == type) out.add(e);
    }
    return out;
  }

  List<Entry> dosesOf(Medication med) => _dosesByMed[med.id] ?? const [];

  /// Today's dose times for [med], with the dose entry that covers each slot
  /// (any dose within half an interval of the slot time).
  List<(DateTime, Entry?)> todaySlots(Medication med) {
    final now = DateTime.now();
    final slots = [
      for (final m in med.slots)
        DateTime(now.year, now.month, now.day, m ~/ 60, m % 60),
    ];
    final taken = List<Entry?>.filled(slots.length, null);
    final window = med.intervalMinutes / 2;
    // Each dose ticks off only the dose time it is closest to.
    for (final d in dosesOf(med)) {
      var best = -1;
      var bestGap = double.infinity;
      for (var i = 0; i < slots.length; i++) {
        final gap = d.time.difference(slots[i]).inMinutes.abs().toDouble();
        if (gap < bestGap) {
          bestGap = gap;
          best = i;
        }
      }
      if (best >= 0 && bestGap <= window && taken[best] == null) {
        taken[best] = d;
      }
    }
    return [for (var i = 0; i < slots.length; i++) (slots[i], taken[i])];
  }

  DateTime nextDose(Medication med) {
    final now = DateTime.now();
    for (final (at, taken) in todaySlots(med)) {
      if (taken == null &&
          at.isAfter(now.subtract(const Duration(minutes: 30)))) {
        return at;
      }
    }
    final first = med.slots.first;
    return DateTime(now.year, now.month, now.day + 1, first ~/ 60, first % 60);
  }

  /// Whether [med] rings on this phone. By default only on the phone that added it.
  bool remindHere(Medication med) =>
      _remindHere[med.id] ??
      (med.remind && (med.createdBy == null || med.createdBy == deviceId));

  String? pillReminderOverride(Medication med, int minutes) =>
      _pillReminderOverrides['${med.id}:$minutes'];

  void setPillReminderOverride(Medication med, int minutes, String? style) {
    final key = '${med.id}:$minutes';
    if (style == null || style == 'default') {
      _pillReminderOverrides.remove(key);
    } else {
      _pillReminderOverrides[key] = style;
      if (style == 'alarm') reminders.requestAlarmPermission();
    }
    _settingsChanged();
  }

  void setPillReminderOverrides(Medication med, Map<int, String> styles) {
    var needsAlarmPermission = false;
    for (final entry in styles.entries) {
      final key = '${med.id}:${entry.key}';
      if (entry.value == 'default') {
        _pillReminderOverrides.remove(key);
      } else {
        _pillReminderOverrides[key] = entry.value;
        needsAlarmPermission |= entry.value == 'alarm';
      }
    }
    if (needsAlarmPermission) reminders.requestAlarmPermission();
    _settingsChanged();
  }

  /// Counts of what is shared, per kind: feed, nappy, pill (doses), med (pills).
  Map<String, int> get counts => {
    'feed': _entries.values
        .where((e) => !e.deleted && e.type == EntryType.feed)
        .length,
    'nappy': _entries.values
        .where((e) => !e.deleted && e.type == EntryType.nappy)
        .length,
    'pill': _visible.where((e) => e.type == EntryType.pill).length,
    'sleep': _entries.values
        .where((e) => !e.deleted && e.type == EntryType.sleep)
        .length,
    'med': _visibleMeds.length,
    'baby': babies.length,
    'routine': _routines.values.where((r) => !r.deleted).length,
    'growth': _growth.values.where((g) => !g.deleted).length,
    'completion': _routineCompletions.values.where((c) => !c.deleted).length,
  };

  // ---------------------------------------------------------------- writing

  /// True if [original] (as opened in an edit screen) was changed since,
  /// e.g. by a sync from the other phone.
  bool changedSince(Syncable original) {
    final now = original is Entry
        ? _entries[original.id]
        : original is Routine
        ? _routines[original.id]
        : _meds[original.id];
    return now != null && now.updatedAt != original.updatedAt;
  }

  /// Edit time for a new version of [id]: now, but always after the version
  /// it replaces, so an edit wins even if the other phone's clock is ahead.
  DateTime _editTime(Syncable? existing) {
    final now = DateTime.now();
    if (existing == null || now.isAfter(existing.updatedAt)) return now;
    return existing.updatedAt.add(const Duration(milliseconds: 1));
  }

  void _touch(String id, {String from = ''}) {
    _seqOf[id] = ++_seq;
    if (from.isEmpty) {
      _from.remove(id);
    } else {
      _from[id] = from;
    }
  }

  /// Adds or replaces (same id) an entry.
  void addEntry(Entry e) {
    final existing = _entries[e.id];
    _entries[e.id] = e.copyWith(
      babyId:
          existing?.babyId ??
          (existing != null ? defaultBabyId : e.babyId ?? activeBabyId),
      updatedAt: _editTime(existing),
      by: existing?.by ?? e.by ?? deviceName,
      byId: existing?.byId ?? e.byId ?? (existing == null ? deviceId : null),
    );
    _touch(e.id);
    _changed();
  }

  /// Replaces an entry (same id) with edited values.
  void updateEntry(Entry e) => addEntry(e);

  void deleteEntry(Entry e) {
    final existing = _entries[e.id] ?? e;
    _entries[e.id] = existing.copyWith(
      updatedAt: _editTime(existing),
      deleted: true,
    );
    _touch(e.id);
    _changed();
  }

  void restoreEntry(Entry e) {
    final existing = _entries[e.id] ?? e;
    _entries[e.id] = existing.copyWith(
      updatedAt: _editTime(existing),
      deleted: false,
    );
    _touch(e.id);
    _changed();
  }

  Entry takePill(Medication med, {DateTime? time}) {
    final e = Entry(
      type: EntryType.pill,
      time: time ?? DateTime.now(),
      medId: med.id,
      medName: med.name,
    );
    addEntry(e);
    return _entries[e.id]!;
  }

  void saveMed(Medication med, {bool? remindHere}) {
    final existing = _meds[med.id];
    _meds[med.id] = med.copyWith(
      createdBy: existing?.createdBy ?? med.createdBy ?? deviceId,
      updatedAt: _editTime(existing),
    );
    if (remindHere != null) _remindHere[med.id] = remindHere;
    _touch(med.id);
    _changed();
  }

  void deleteMed(Medication med) => saveMed(med.copyWith(deleted: true));

  void startFeedTimer(FeedSide side, {DateTime? now}) {
    if (timerStart != null) return;
    timerSide = side;
    timerStart = now ?? DateTime.now();
    timerPausedAt = null;
    timerPausedMilliseconds = 0;
    if (timerReminders) {
      unawaited(
        reminders.requestPermission().then((_) => _rescheduleReminders()),
      );
    }
    _settingsChanged();
  }

  void pauseFeedTimer({DateTime? now}) {
    if (timerStart == null || timerPaused) return;
    timerPausedAt = now ?? DateTime.now();
    _settingsChanged();
  }

  void resumeFeedTimer({DateTime? now}) {
    if (!timerPaused) return;
    timerPausedMilliseconds += max(
      0,
      (now ?? DateTime.now()).difference(timerPausedAt!).inMilliseconds,
    );
    timerPausedAt = null;
    _settingsChanged();
  }

  void setTimerReminders(bool enabled) {
    timerReminders = enabled;
    if (enabled) {
      unawaited(
        reminders.requestPermission().then((_) => _rescheduleReminders()),
      );
    }
    _settingsChanged();
  }

  void switchTimerSide(FeedSide side) {
    timerSide = side;
    _settingsChanged();
  }

  void stopFeedTimer({bool save = true, DateTime? now}) {
    final elapsed = feedElapsed(now);
    final side = timerSide, start = timerStart;
    timerSide = null;
    timerStart = null;
    timerPausedAt = null;
    timerPausedMilliseconds = 0;
    if (save && side != null && start != null) {
      final mins = max(1, (elapsed.inSeconds / 60).round());
      addEntry(
        Entry(type: EntryType.feed, time: start, side: side, durationMin: mins),
      );
    } else {
      _settingsChanged();
    }
  }

  void setFeedReminder({bool? on, int? minutes}) {
    feedReminderOn = on ?? feedReminderOn;
    feedReminderMinutes = minutes ?? feedReminderMinutes;
    _settingsChanged();
  }

  void setReminderAlarm({bool? feed, bool? pill}) {
    feedAlarm = feed ?? feedAlarm;
    pillAlarm = pill ?? pillAlarm;
    if (feed == true || pill == true) reminders.requestAlarmPermission();
    _settingsChanged();
  }

  void setAutoSync(bool on) {
    autoSync = on;
    _settingsChanged();
  }

  void setBackgroundSync(bool on) {
    backgroundSync = on;
    _settingsChanged();
    _applyBackground();
  }

  Future<void> requestBatteryExempt() => BackgroundSync.requestBatteryExempt();

  void _applyBackground() {
    if (backgroundSync && peers.isNotEmpty) {
      BackgroundSync.start();
    } else {
      BackgroundSync.stop();
    }
  }

  void setAppearance(String value) {
    appearance = value;
    _settingsChanged();
  }

  void setNightLight(bool on) {
    nightLight = on;
    _settingsChanged();
  }

  void completeSetup() {
    setupDone = true;
    _settingsChanged();
    reminders.requestPermission();
  }

  void restartSetup() {
    setupDone = false;
    _settingsChanged();
  }

  void setBabyName(String name) {
    final existing = _babies[activeBabyId];
    final baby = BabyProfile(
      id: activeBabyId,
      name: name.trim(),
      dateOfBirth: existing?.dateOfBirth,
      photo: existing?.photo,
      updatedAt: _editTime(existing),
    );
    _babies[baby.id] = baby;
    _touch(baby.id);
    _changed();
  }

  /// Most recent successful sync with any paired device.
  DateTime? get lastSync {
    DateTime? best;
    for (final p in peers) {
      final t = p.lastSync;
      if (t != null && (best == null || t.isAfter(best))) best = t;
    }
    return best;
  }

  /// Nothing worked: every device we have actually reached before (or paired
  /// ourselves) failed. Members only learned through the hub and not yet
  /// reached do not count, and one member being off does not either.
  bool get syncHasError {
    final counted = peers.where((p) => !p.neverReached).toList();
    return counted.isNotEmpty && counted.every((p) => p.lastError != null);
  }

  bool get syncPausedForVersion => peers.any((p) => p.blockedVersion != null);

  void setDeviceName(String name) {
    if (name.trim().isEmpty) return;
    deviceName = name.trim();
    deviceNameCustom = true;
    _settingsChanged();
  }

  /// Goes back to the name the device itself reports.
  Future<void> useDeviceOwnName() async {
    deviceNameCustom = false;
    deviceName = await DeviceIdentity.name() ?? deviceName;
    _settingsChanged();
  }

  void forgetPeer(Peer p) {
    peers.remove(p);
    _removedPeers.add(p.deviceId);
    _settingsChanged();
    _applyBackground();
  }

  /// Sync with [p] even though its app version differs.
  Future<void> acceptVersion(Peer p) async {
    p.acceptedVersion = p.blockedVersion ?? p.appVersion;
    p.blockedVersion = null;
    p.pausedByUser = false;
    p.lastError = null;
    _changed(shared: false);
    await syncPeer(p);
  }

  /// Stop syncing with [p] again while its version differs.
  void pauseForVersion(Peer p) {
    p.acceptedVersion = null;
    p.pausedByUser = true;
    if (p.appVersion != null && !sameFeatures(p.appVersion)) {
      p.blockedVersion = p.appVersion;
    }
    _changed(shared: false);
  }

  /// Forget what was already exchanged with [p], so the next sync sends everything.
  Future<void> resyncEverything(Peer p) async {
    p.ackedSeq = 0;
    p.theirSeq = 0;
    _changed(shared: false);
    await syncPeer(p);
  }

  /// Re-reads things that can change while the app is away: IP, battery setting.
  Future<void> refreshIps() async {
    final before = ips.isEmpty ? null : ips.first;
    ips = await localIps();
    batteryExempt = await BackgroundSync.isBatteryExempt();
    notifyListeners();
    // Our address changed: contacting the paired phones tells them the new one.
    if (before != null && ips.isNotEmpty && ips.first != before) {
      unawaited(syncAll(quiet: true));
    }
  }

  /// Something shared or a setting changed: save, update the screen and
  /// reminders, and (for shared data) push it to the paired phones.
  void _changed({bool shared = true}) {
    _rebuild();
    _metaSave?.cancel();
    _metaSave = null;
    _peersDirty = false;
    _save();
    notifyListeners();
    _rescheduleReminders();
    if (shared && autoSync && peers.isNotEmpty) {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(
        const Duration(seconds: 1),
        () => syncAll(quiet: true),
      );
    }
  }

  /// A setting on this phone changed (nothing shared): save and update the
  /// screen, without rebuilding the lists.
  void _settingsChanged() {
    _metaSave?.cancel();
    _metaSave = null;
    _peersDirty = false;
    _save();
    notifyListeners();
    _rescheduleReminders();
  }

  /// Only sync details changed (last sync time, stats): update the screen now
  /// and save a little later, so idle syncs do not write the file every minute.
  void _metaChanged({bool notify = true}) {
    if (notify) notifyListeners();
    if (_peersDirty) {
      _peersDirty = false;
      _metaSave?.cancel();
      _metaSave = null;
      _save();
      return;
    }
    _metaSave ??= Timer(const Duration(minutes: 5), flush);
  }

  void _rebuild() {
    if (_babies.isEmpty) {
      final baby = BabyProfile(
        id: defaultBabyId,
        name: _legacyBabyName,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      _babies[baby.id] = baby;
      _touch(baby.id);
    }
    if (!_babies.containsKey(activeBabyId) || _babies[activeBabyId]!.deleted) {
      activeBabyId = babies.first.id;
    }
    _visible =
        _entries.values
            .where(
              (e) =>
                  !e.deleted &&
                  (e.type == EntryType.pill ||
                      (e.babyId ?? defaultBabyId) == activeBabyId),
            )
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    _visibleMeds = _meds.values.where((m) => !m.deleted).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _dosesByMed = {};
    for (final e in _visible) {
      if (e.type == EntryType.pill && e.medId != null) {
        (_dosesByMed[e.medId!] ??= []).add(e);
      }
    }

    // Same kind of entry from two different phones within 10 minutes.
    final dups = <String>{};
    for (var i = 0; i < _visible.length; i++) {
      final a = _visible[i];
      for (var j = i + 1; j < _visible.length; j++) {
        final b = _visible[j];
        if (a.time.difference(b.time).inMinutes >= 10) break;
        final sameKind =
            a.type == b.type &&
            (a.type != EntryType.nappy || a.nappy == b.nappy) &&
            (a.type != EntryType.pill || a.medId == b.medId);
        final aBy = a.byId ?? a.by, bBy = b.byId ?? b.by;
        if (sameKind && aBy != null && bBy != null && aBy != bBy) {
          dups
            ..add(a.id)
            ..add(b.id);
        }
      }
    }
    _possibleDuplicates = dups;
  }

  void _rescheduleReminders() {
    reminders.scheduleFeedingTimer(
      origin: timerActiveOrigin,
      babyName: babyName,
    );
    reminders.reschedule(
      babyFeeds: [
        for (final baby in babies)
          if (_feedReminderOn[baby.id] == true)
            (babyId: baby.id, name: baby.name, at: _feedAtFor(baby.id)),
      ],
      routineReminders: [
        for (final r in _routines.values)
          if (!r.deleted &&
              r.enabled &&
              routineRemindsHere(r) &&
              _babies[r.babyId]?.deleted == false)
            (
              routine: r,
              babyName: _babies[r.babyId]!.name,
              completedAt: lastRoutineCompletion(r)?.time,
            ),
      ],
      meds: _visibleMeds.where(remindHere).toList(),
      feedAlarm: feedAlarm,
      pillAlarm: pillAlarm,
      pillReminderOverrides: _pillReminderOverrides,
    );
  }

  DateTime? _feedAtFor(String babyId) {
    DateTime? last;
    for (final e in _entries.values) {
      if (!e.deleted &&
          e.type == EntryType.feed &&
          (e.babyId ?? defaultBabyId) == babyId &&
          (last == null || e.time.isAfter(last))) {
        last = e.time;
      }
    }
    return last?.add(Duration(minutes: _feedReminderMinutes[babyId] ?? 180));
  }

  // ---------------------------------------------------------------- sync

  Map<String, dynamic> get _me => {
    'deviceId': deviceId,
    'key': syncKey,
    'port': server.port ?? defaultSyncPort,
    'name': deviceName,
    'babyName': babyName,
    'appVersion': appVersion,
  };

  /// Records changed here after [since], leaving out ones that came from [to].
  ({
    List<Map<String, dynamic>> entries,
    List<Map<String, dynamic>> meds,
    List<Map<String, dynamic>> babies,
    List<Map<String, dynamic>> routines,
    List<Map<String, dynamic>> completions,
    List<Map<String, dynamic>> growth,
  })
  _changesSince(int since, String to) {
    bool send(String id) => (_seqOf[id] ?? 0) > since && _from[id] != to;
    return (
      growth: [
        for (final g in _growth.values)
          if (since == 0 || send(g.id)) g.toJson(),
      ],
      babies: [
        for (final b in _babies.values)
          if (since == 0 || send(b.id)) b.toJson(),
      ],
      completions: [
        for (final c in _routineCompletions.values)
          if (since == 0 || send(c.id)) c.toJson(),
      ],
      routines: [
        for (final r in _routines.values)
          if (since == 0 || send(r.id)) r.toJson(),
      ],
      entries: [
        for (final e in _entries.values)
          if (since == 0 || send(e.id)) e.toJson(),
      ],
      meds: [
        for (final m in _meds.values)
          if (since == 0 || send(m.id)) m.toJson(),
      ],
    );
  }

  /// Merges records from [body]; returns how many were new or newer, per kind.
  static List<T> _decode<T>(
    Object? list,
    T? Function(Map<String, dynamic>) parse,
  ) => [
    for (final j in list is List ? list : const [])
      if (j is Map) ?_tryParse(() => parse(Map<String, dynamic>.from(j))),
  ];

  static T? _tryParse<T>(T? Function() parse) {
    try {
      return parse();
    } catch (e) {
      debugPrint('Skipping a malformed record: $e');
      return null;
    }
  }

  Map<String, int> _mergePayload(
    Map<String, dynamic> body, {
    String from = '',
  }) {
    final entries = _decode(body['entries'], Entry.fromJson);
    final meds = _decode(body['meds'], Medication.fromJson);
    final counts = <String, int>{};
    final legacyName =
        body['babyName'] as String? ??
        (body['from'] is Map
            ? (body['from'] as Map)['babyName'] as String?
            : null) ??
        '';
    final legacyBaby = _babies[defaultBabyId];
    final legacyProfiles = !body.containsKey('babies');
    if (legacyProfiles &&
        legacyName.isNotEmpty &&
        (legacyBaby == null || legacyBaby.name.isEmpty)) {
      final baby = BabyProfile(
        id: defaultBabyId,
        name: legacyName,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      _babies[baby.id] = baby;
      _touch(baby.id, from: from);
      counts['baby'] = 1;
    }
    for (final s in <Syncable>[
      ...mergeChanged(_growth, _decode(body['growth'], GrowthEntry.fromJson)),
      ...mergeChanged(_babies, _decode(body['babies'], BabyProfile.fromJson)),
      ...mergeChanged(_routines, _decode(body['routines'], Routine.fromJson)),
      ...mergeChanged(
        _routineCompletions,
        _decode(body['completions'], RoutineCompletion.fromJson),
      ),
      ...mergeChanged(_entries, entries),
      ...mergeChanged(_meds, meds),
    ]) {
      _touch(s.id, from: from);
      final kind = s is GrowthEntry
          ? 'growth'
          : s is RoutineCompletion
          ? 'completion'
          : s is BabyProfile
          ? 'baby'
          : s is Routine
          ? 'routine'
          : kindOf(s);
      counts.update(kind, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// This device's view of the hub, for other members: everyone we know
  /// except ourselves (we describe ourselves in `from`).
  List<Map<String, dynamic>> get _members => [
    for (final p in peers)
      if (p.key.isNotEmpty && p.deviceId != deviceId) p.toMemberJson(),
  ];

  /// Adds hub members told to us by another member. Never replaces what we
  /// know first-hand: a working key stays, an address is only filled in when
  /// we have none or ours keeps failing. Devices removed here stay removed.
  void _learnMembers(Object? list) {
    if (list is! List) return;
    var added = false;
    for (final m in list) {
      if (m is! Map) continue;
      final id = m['deviceId'];
      final key = m['key'];
      if (id is! String || id.isEmpty || id == deviceId) continue;
      if (key is! String || key.isEmpty || _removedPeers.contains(id)) continue;
      final host = m['host'] is String ? m['host'] as String : '';
      final port = (m['port'] as num?)?.toInt() ?? defaultSyncPort;
      final name = m['name'] is String ? m['name'] as String : '';
      final known = peers.where((p) => p.deviceId == id).firstOrNull;
      if (known == null) {
        peers.add(
          Peer(deviceId: id, host: host, port: port, key: key, name: name)
            ..learnedFromHub = true,
        );
        added = true;
        _peersDirty = true;
        continue;
      }
      if (known.key.isEmpty) known.key = key;
      if (known.name.isEmpty && name.isNotEmpty) known.name = name;
      if (host.isNotEmpty &&
          (known.host.isEmpty ||
              (known.failures >= 3 && known.host != host))) {
        known.host = host;
        known.port = port;
        _peersDirty = true;
      }
    }
    if (added) Future.microtask(_applyBackground);
  }

  Peer _rememberPeer(Map<String, dynamic> from, String? host) {
    final id = from['deviceId'] as String;
    _removedPeers.remove(id);
    final port = (from['port'] as num?)?.toInt() ?? defaultSyncPort;
    final key = from['key'] as String?;
    final name = from['name'] as String? ?? '';
    for (final p in peers) {
      if (p.deviceId == id) {
        host ??= p.host;
        if (p.host != host || p.port != port || (key != null && p.key != key)) {
          _peersDirty = true;
        }
        p
          ..host = host
          ..port = port
          ..key = key ?? p.key
          ..name = name.isEmpty ? p.name : name;
        return p;
      }
    }
    final p = Peer(
      deviceId: id,
      host: host ?? '',
      port: port,
      key: key ?? '',
      name: name,
    );
    peers.add(p);
    _peersDirty = true;
    // First pairing: start syncing in the background too.
    Future.microtask(_applyBackground);
    return p;
  }

  SyncReply _handleInfo(String key, String askerId) {
    if (key != syncKey) return (status: HttpStatus.forbidden, body: null);
    return (
      status: HttpStatus.ok,
      body: {
        ..._me,
        'counts': counts,
        'seq': _seq,
        'knowsYou': peers.any((p) => p.deviceId == askerId),
        'members': _members,
      }..remove('key'),
    );
  }

  Future<SyncReply> _handleIncoming(
    Map<String, dynamic> body,
    String remoteIp,
  ) => BackgroundSync.whileAwake(() async {
    if (body['key'] != syncKey) {
      return (status: HttpStatus.forbidden, body: null);
    }
    final from = body['from'];
    if (from is! Map ||
        from['deviceId'] is! String ||
        from['deviceId'] == deviceId) {
      return (status: HttpStatus.badRequest, body: null);
    }
    final peer = _rememberPeer(Map<String, dynamic>.from(from), remoteIp);
    _learnMembers(body['members']);

    // Different app versions only sync if one of the two phones accepted it.
    final theirVersion = from['appVersion'] as String? ?? olderVersion;
    peer.appVersion = theirVersion;
    if (!sameFeatures(theirVersion)) {
      if (sameFeatures(body['acceptVersion'] as String?) &&
          !peer.pausedByUser) {
        peer.acceptedVersion = theirVersion;
      } else if (!_accepted(peer.acceptedVersion, theirVersion)) {
        peer.blockedVersion = theirVersion;
        _changed(shared: false);
        return (
          status: HttpStatus.conflict,
          body: {'error': 'version', 'from': _me},
        );
      }
    }
    peer.blockedVersion = null;

    // Old versions send everything and expect everything back.
    final since = (body['since'] as num?)?.toInt() ?? 0;
    final theirSeq = (body['seq'] as num?)?.toInt();
    final reply = _changesSince(since, peer.deviceId);
    final newHere = _mergePayload(body, from: peer.deviceId);
    if (theirSeq != null) peer.theirSeq = max(peer.theirSeq, theirSeq);
    final received =
        (body['entries'] as List? ?? []).length +
        (body['meds'] as List? ?? []).length +
        (body['babies'] as List? ?? []).length +
        (body['routines'] as List? ?? []).length +
        (body['growth'] as List? ?? []).length +
        (body['completions'] as List? ?? []).length;
    peer.record(
      SyncRecord(
        at: DateTime.now(),
        outgoing: false,
        sent:
            reply.entries.length +
            reply.meds.length +
            reply.babies.length +
            reply.routines.length +
            reply.completions.length +
            reply.growth.length,
        received: received,
        newThere: 0,
        newHere: newHere,
        bytes: 0,
      ),
    );
    if (newHere.isNotEmpty) {
      _changed(shared: false);
      await _saving;
    } else {
      _metaChanged(notify: false);
    }
    return (
      status: HttpStatus.ok,
      body: {
        'v': 2,
        'from': _me,
        'members': _members,
        'seq': _seq,
        'took': newHere,
        'entries': reply.entries,
        'meds': reply.meds,
        'babies': reply.babies,
        'routines': reply.routines,
        'completions': reply.completions,
        'growth': reply.growth,
      },
    );
  });

  /// Exchanges changes with [p]: asks which version it runs, then sends what
  /// changed here and merges what changed there.
  Future<void> _syncWith(Peer p) async {
    final info = await getInfo(p.host, p.port, p.key, deviceId);
    if (info['deviceId'] is String && info['deviceId'] != p.deviceId) {
      throw UnreachableException('A different device answered at ${p.host}');
    }
    final theirVersion = info['appVersion'] as String? ?? olderVersion;
    p.appVersion = theirVersion;
    _learnMembers(info['members']);
    if (info['name'] is String) p.name = info['name'];
    if (info['counts'] is Map) {
      p.remoteCounts = {
        for (final e in (info['counts'] as Map).entries)
          '${e.key}': (e.value as num).toInt(),
      };
    }
    if (!sameFeatures(theirVersion) &&
        !_accepted(p.acceptedVersion, theirVersion)) {
      p.blockedVersion = theirVersion;
      throw VersionMismatchException(p.deviceId, theirVersion);
    }
    p.blockedVersion = null;

    // Their counter went backwards: their data was reset, so start over.
    final theirNow = (info['seq'] as num?)?.toInt();
    if (theirNow != null && theirNow < p.theirSeq) {
      p.theirSeq = 0;
      p.ackedSeq = 0;
    }

    final sentUpTo = _seq;
    final changes = _changesSince(p.ackedSeq, p.deviceId);
    // Nothing new on either side, and it already knows this phone: the quick
    // /info check was enough.
    if (changes.entries.isEmpty &&
        changes.meds.isEmpty &&
        changes.babies.isEmpty &&
        changes.routines.isEmpty &&
        changes.completions.isEmpty &&
        changes.growth.isEmpty &&
        info['knowsYou'] == true &&
        theirNow != null &&
        theirNow == p.theirSeq) {
      final hadError = p.lastError != null;
      p
        ..lastSync = DateTime.now()
        ..lastError = null
        ..failures = 0
        ..unreachable = false
        ..ackedSeq = sentUpTo;
      _metaChanged(notify: hadError);
      return;
    }
    final res = await postSync(p.host, p.port, {
      'v': 2,
      'key': p.key,
      'from': _me,
      'members': _members,
      if (!sameFeatures(theirVersion)) 'acceptVersion': theirVersion,
      'since': p.theirSeq,
      'seq': sentUpTo,
      'entries': changes.entries,
      'meds': changes.meds,
      'babies': changes.babies,
      'routines': changes.routines,
      'completions': changes.completions,
      'growth': changes.growth,
    });
    if (res.status == HttpStatus.conflict) {
      p.blockedVersion = theirVersion;
      throw VersionMismatchException(p.deviceId, theirVersion);
    }

    _learnMembers(res.body['members']);
    final newHere = _mergePayload(res.body, from: p.deviceId);
    p.ackedSeq = sentUpTo;
    final theirSeq = (res.body['seq'] as num?)?.toInt();
    if (theirSeq != null) p.theirSeq = theirSeq;
    final took =
        (res.body['took'] as Map?)?.values.fold<int>(
          0,
          (a, b) => a + (b as num).toInt(),
        ) ??
        0;
    p.record(
      SyncRecord(
        at: DateTime.now(),
        outgoing: true,
        sent:
            changes.entries.length +
            changes.meds.length +
            changes.babies.length +
            changes.routines.length +
            changes.completions.length +
            changes.growth.length,
        received:
            (res.body['entries'] as List? ?? []).length +
            (res.body['meds'] as List? ?? []).length +
            (res.body['babies'] as List? ?? []).length +
            (res.body['routines'] as List? ?? []).length +
            (res.body['completions'] as List? ?? []).length +
            (res.body['growth'] as List? ?? []).length,
        newThere: took,
        newHere: newHere,
        bytes: res.bytes,
      ),
    );
    if (newHere.isNotEmpty) {
      _changed(shared: false);
    } else {
      _metaChanged(notify: false);
    }
  }

  final Map<String, DateTime> _lastSearch = {};

  /// Looks for [p] on this Wi-Fi when its address stopped working. Only
  /// while the app is on screen (or when [force]d by the user), and at most
  /// every 10 minutes per device, to save battery. Returns true if found.
  Future<bool> findPeer(Peer p, {bool force = false}) async {
    if (ips.isEmpty) return false;
    final last = _lastSearch[p.deviceId];
    if (!force &&
        (_syncPeriodic == null ||
            (last != null && DateTime.now().difference(last).inMinutes < 10))) {
      return false;
    }
    _lastSearch[p.deviceId] = DateTime.now();
    final host = await findOnNetwork(
      ownIp: ips.first,
      port: p.port,
      key: p.key,
      myId: deviceId,
      deviceId: p.deviceId,
    );
    if (host == null) return false;
    p.host = host;
    _peersDirty = true;
    _metaChanged();
    return true;
  }

  /// Syncs with [p]; if it cannot be reached, looks for it on the network
  /// and tries once more at the new address.
  Future<void> _syncFinding(Peer p, {bool force = false}) async {
    try {
      await _syncWith(p);
    } on UnreachableException {
      if (!await findPeer(p, force: force)) rethrow;
      await _syncWith(p);
    }
  }

  /// First connection to another device, from its QR code or typed code.
  /// Throws [VersionMismatchException] if its app version differs; the device
  /// is then paired but syncing waits for [acceptVersion].
  /// The sync running now, if any. Syncs run one at a time.
  Future<void>? _running;

  /// A change happened during a sync: run another one when it finishes.
  bool _syncAgain = false;

  Future<void> _waitForRunning() async {
    while (_running != null) {
      await _running;
    }
  }

  /// Runs [work] as the only sync, with the busy indicator on.
  Future<T> _exclusive<T>(Future<T> Function() work, {bool show = true}) async {
    await _waitForRunning();
    final done = Completer<void>();
    _running = done.future;
    syncing = true;
    if (show) notifyListeners();
    try {
      return await work();
    } finally {
      syncing = false;
      _running = null;
      done.complete();
      if (show) notifyListeners();
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncAll(quiet: true));
      }
    }
  }

  Future<Peer> pair(String host, int port, String key) => _exclusive(() async {
    host = host.trim();
    key = key.trim();
    final info = await getInfo(host, port, key, deviceId);
    if (info['deviceId'] is! String) {
      throw SyncException(
        'The other phone has an older version of Nestling. Install the same version on both phones.',
      );
    }
    if (info['deviceId'] == deviceId) {
      throw SyncException('That is this device');
    }
    final peer = _rememberPeer({...info, 'key': key, 'port': port}, host);
    _changed(shared: false);
    try {
      await BackgroundSync.whileAwake(() => _syncWith(peer));
    } on VersionMismatchException {
      rethrow;
    } catch (e) {
      _noteFailure(peer, e);
      throw SyncException(
        'Paired, but the first sync failed: $e. It will try again by itself.',
      );
    }
    return peer;
  });

  /// Syncs with one paired device now. Throws on failure.
  Future<void> syncPeer(Peer p) => _exclusive(() async {
    try {
      await BackgroundSync.whileAwake(() => _syncFinding(p, force: true));
    } catch (e) {
      _noteFailure(p, e);
      _metaChanged(notify: false);
      rethrow;
    }
  });

  void _noteFailure(Peer p, Object e) {
    p.lastError = e.toString();
    p.failures++;
    p.unreachable = e is UnreachableException;
  }

  /// Syncs with every paired device. Returns an error message, or null.
  /// [force]: the user asked (pull to refresh), so a phone that moved is
  /// looked for on the network right away.
  Future<String?> syncAll({bool quiet = false, bool force = false}) async {
    if (peers.isEmpty || (quiet && !autoSync)) return null;
    if (_running != null && quiet) {
      _syncAgain = true;
      return null;
    }
    var errorsChanged = false;
    String? error;
    await _exclusive(
      show: !quiet,
      () => BackgroundSync.whileAwake(() async {
        for (final p in List.of(peers)) {
          final before = p.lastError;
          try {
            await _syncFinding(p, force: force);
          } catch (e) {
            _noteFailure(p, e);
            // A member learned through the hub that is simply off or elsewhere
            // is not worth an error message.
            if (!(p.learnedFromHub && e is UnreachableException)) {
              error = '${p.name.isEmpty ? p.host : p.name}: $e';
            }
          }
          if (p.lastError != before) errorsChanged = true;
        }
      }),
    );
    // Quiet syncs that changed nothing visible do not redraw the screen.
    if (quiet && errorsChanged) notifyListeners();
    return error;
  }

  // ---------------------------------------------------------------- QR sync

  /// QR codes with what [to] has not got yet (everything for a new phone).
  /// Also carries this phone's code, so the two can sync over Wi-Fi later.
  List<String> qrCodesFor(Peer? to) {
    final changes = _changesSince(to?.ackedSeq ?? 0, to?.deviceId ?? '');
    return QrTransfer.encode({
      'app': 'babylog-qr',
      'from': _me,
      'members': _members,
      'seq': _seq,
      'ack': to?.theirSeq ?? 0,
      'entries': changes.entries,
      'meds': changes.meds,
      'babies': changes.babies,
      'routines': changes.routines,
      'completions': changes.completions,
      'growth': changes.growth,
    });
  }

  /// Merges data scanned from another phone's QR codes. Throws
  /// [VersionMismatchException] if its app version differs and [acceptVersion]
  /// is false. Returns the phone and what was new here.
  ({Peer peer, Map<String, int> newHere}) receiveQr(
    Map<String, dynamic> body, {
    bool acceptVersion = false,
  }) {
    final from = body['from'];
    if (body['app'] != 'babylog-qr' ||
        from is! Map ||
        from['deviceId'] is! String) {
      throw SyncException('That is not a Nestling sync code');
    }
    if (from['deviceId'] == deviceId) {
      throw SyncException('That code is from this phone');
    }
    final theirVersion = from['appVersion'] as String? ?? olderVersion;
    final known = peers
        .where((p) => p.deviceId == from['deviceId'])
        .firstOrNull;
    if (!sameFeatures(theirVersion) &&
        !_accepted(known?.acceptedVersion, theirVersion) &&
        !acceptVersion) {
      throw VersionMismatchException(from['deviceId'] as String, theirVersion);
    }
    final peer = _rememberPeer(Map<String, dynamic>.from(from), null);
    _learnMembers(body['members']);
    peer.appVersion = theirVersion;
    if (!sameFeatures(theirVersion)) peer.acceptedVersion = theirVersion;
    peer.blockedVersion = null;
    final newHere = _mergePayload(body, from: peer.deviceId);
    final theirSeq = (body['seq'] as num?)?.toInt();
    if (theirSeq != null) peer.theirSeq = max(peer.theirSeq, theirSeq);
    peer.ackedSeq = (body['ack'] as num?)?.toInt() ?? peer.ackedSeq;
    peer.record(
      SyncRecord(
        at: DateTime.now(),
        outgoing: false,
        sent: 0,
        received:
            (body['entries'] as List? ?? []).length +
            (body['meds'] as List? ?? []).length +
            (body['babies'] as List? ?? []).length +
            (body['routines'] as List? ?? []).length +
            (body['growth'] as List? ?? []).length +
            (body['completions'] as List? ?? []).length,
        newThere: 0,
        newHere: newHere,
        bytes: 0,
      ),
    );
    _peersDirty = false;
    _changed(shared: false);
    _applyBackground();
    return (peer: peer, newHere: newHere);
  }

  // ---------------------------------------------------------------- backup

  /// Everything shared (entries, pills, deletions) as a backup file.
  String exportBackup() => const JsonEncoder.withIndent(' ').convert({
    'app': 'babylog',
    'v': 1,
    'appVersion': appVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'babyName': babyName,
    'entries': [for (final e in _entries.values) e.toJson()],
    'meds': [for (final m in _meds.values) m.toJson()],
    'babies': [for (final b in _babies.values) b.toJson()],
    'routines': [for (final r in _routines.values) r.toJson()],
    'completions': [for (final c in _routineCompletions.values) c.toJson()],
    'growth': [for (final g in _growth.values) g.toJson()],
  });

  /// Merges a backup into the log (newest copy of each record wins, nothing
  /// is lost). Returns how many entries and pills were new or newer.
  ({
    int entries,
    int meds,
    int babies,
    int routines,
    int completions,
    int growth,
  })
  importBackup(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic> ||
        (j['app'] != 'babylog' &&
            !(j['deviceId'] is String && j['entries'] is List))) {
      throw const FormatException('This is not a Nestling backup file');
    }
    final counts = _mergePayload(j);
    _changed();
    final entries = counts.entries
        .where((e) => ['feed', 'nappy', 'pill', 'sleep'].contains(e.key))
        .fold<int>(0, (a, e) => a + e.value);
    return (
      entries: entries,
      meds: counts['med'] ?? 0,
      babies: counts['baby'] ?? 0,
      routines: counts['routine'] ?? 0,
      completions: counts['completion'] ?? 0,
      growth: counts['growth'] ?? 0,
    );
  }

  // ---------------------------------------------------------------- storage

  /// Loads the data file. Returns false if it had no device id or sync code yet.
  Future<bool> _read() async {
    if (!await _file.exists()) return false;
    try {
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      final hadIds = j['deviceId'] is String && j['syncKey'] is String;
      deviceId = j['deviceId'] as String? ?? deviceId;
      syncKey = j['syncKey'] as String? ?? syncKey;
      deviceName = j['deviceName'] as String? ?? deviceName;
      // Older files had no flag: only the built-in defaults were not typed.
      deviceNameCustom =
          j['deviceNameCustom'] as bool? ??
          !{'Phone', Platform.localHostname}.contains(deviceName);
      _legacyBabyName = j['babyName'] as String? ?? '';
      activeBabyId = j['activeBabyId'] as String? ?? defaultBabyId;
      caregiverName = j['caregiverName'] as String? ?? '';
      language = j['language'] == 'af' ? 'af' : 'en';
      changelogSeenVersion = j['changelogSeenVersion'] as String? ?? '';
      _routineRemindHere.addAll(
        Map<String, bool>.from(j['routineRemindHere'] as Map? ?? {}),
      );
      _feedReminderOn.addAll(
        Map<String, bool>.from(j['babyFeedReminderOn'] as Map? ?? {}),
      );
      _feedReminderMinutes.addAll(
        Map<String, int>.from(j['babyFeedReminderMinutes'] as Map? ?? {}),
      );
      appearance = j['appearance'] as String? ?? 'light';
      nightLight = j['nightLight'] as bool? ?? true;
      setupDone = j['setupDone'] as bool? ?? false;
      if (!j.containsKey('babyFeedReminderOn')) {
        _feedReminderOn[defaultBabyId] = j['feedReminderOn'] as bool? ?? false;
      }
      if (!j.containsKey('babyFeedReminderMinutes')) {
        _feedReminderMinutes[defaultBabyId] =
            (j['feedReminderMinutes'] as num?)?.toInt() ?? 180;
      }
      feedAlarm = j['feedAlarm'] as bool? ?? false;
      pillAlarm = j['pillAlarm'] as bool? ?? false;
      autoSync = j['autoSync'] as bool? ?? true;
      backgroundSync = j['backgroundSync'] as bool? ?? true;
      timerSide = FeedSide.values
          .where((s) => s.name == j['timerSide'])
          .firstOrNull;
      timerStart = j['timerStart'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['timerStart']);
      timerPausedAt = j['timerPausedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['timerPausedAt']);
      timerPausedMilliseconds = max(
        0,
        (j['timerPausedMilliseconds'] as num?)?.toInt() ?? 0,
      );
      timerReminders = j['timerReminders'] != false;
      final remind = Map<String, dynamic>.from(j['remindHere'] as Map? ?? {});
      final pillOverrides = Map<String, dynamic>.from(
        j['pillReminderOverrides'] as Map? ?? {},
      );
      final loadedPeers = [
        for (final p in j['peers'] as List? ?? [])
          Peer.fromJson(Map<String, dynamic>.from(p)),
      ];
      final seqs = Map<String, dynamic>.from(j['seqs'] as Map? ?? {});
      final origins = Map<String, String>.from(j['origins'] as Map? ?? {});
      for (final e in remind.entries) {
        _remindHere[e.key] = e.value == true;
      }
      for (final e in pillOverrides.entries) {
        if (e.value is String) {
          _pillReminderOverrides[e.key] = e.value as String;
        }
      }
      _mergePayload(j);
      // Restore the change counter; files from before it existed get fresh numbers.
      if (seqs.isNotEmpty) {
        _seqOf
          ..clear()
          ..addAll({
            for (final e in seqs.entries) e.key: (e.value as num).toInt(),
          });
        _seq = (j['seq'] as num?)?.toInt() ?? _seqOf.values.fold(0, max);
      }
      _from
        ..clear()
        ..addAll(origins);
      peers.addAll(loadedPeers);
      _removedPeers
        ..clear()
        ..addAll([
          for (final id in j['removedPeers'] as List? ?? [])
            if (id is String) id,
        ]);
      return hadIds;
    } catch (e) {
      debugPrint('Could not read ${_file.path}: $e');
      // Keep the unreadable file (it can be imported again from Settings)
      // and start clean rather than with half-loaded data.
      final copy =
          '${_file.path}.broken-${DateTime.now().millisecondsSinceEpoch}.json';
      await _file.copy(copy);
      loadProblem = copy;
      _entries.clear();
      _meds.clear();
      _babies.clear();
      _growth.clear();
      _routines.clear();
      _routineCompletions.clear();
      activeBabyId = defaultBabyId;
      peers.clear();
      _removedPeers.clear();
      _seqOf.clear();
      _from.clear();
      _remindHere.clear();
      _pillReminderOverrides.clear();
      _seq = 0;
      return true;
    }
  }

  void _save() {
    if (!_persist) return;
    final json = jsonEncode({
      'v': 2,
      'deviceId': deviceId,
      'syncKey': syncKey,
      'deviceName': deviceName,
      'deviceNameCustom': deviceNameCustom,
      'babyName': babyName,
      'activeBabyId': activeBabyId,
      'caregiverName': caregiverName,
      'language': language,
      'changelogSeenVersion': changelogSeenVersion,
      'routineRemindHere': _routineRemindHere,
      'babyFeedReminderOn': _feedReminderOn,
      'babyFeedReminderMinutes': _feedReminderMinutes,
      'appearance': appearance,
      'nightLight': nightLight,
      'setupDone': setupDone,
      'feedReminderOn': _feedReminderOn[defaultBabyId] ?? false,
      'feedReminderMinutes': _feedReminderMinutes[defaultBabyId] ?? 180,
      'feedAlarm': feedAlarm,
      'pillAlarm': pillAlarm,
      'autoSync': autoSync,
      'backgroundSync': backgroundSync,
      'timerSide': timerSide?.name,
      'timerStart': timerStart?.millisecondsSinceEpoch,
      'timerPausedAt': timerPausedAt?.millisecondsSinceEpoch,
      'timerPausedMilliseconds': timerPausedMilliseconds,
      'timerReminders': timerReminders,
      'remindHere': _remindHere,
      'pillReminderOverrides': _pillReminderOverrides,
      'entries': [for (final e in _entries.values) e.toJson()],
      'meds': [for (final m in _meds.values) m.toJson()],
      'babies': [for (final b in _babies.values) b.toJson()],
      'routines': [for (final r in _routines.values) r.toJson()],
      'completions': [for (final c in _routineCompletions.values) c.toJson()],
      'growth': [for (final g in _growth.values) g.toJson()],
      'seq': _seq,
      'seqs': _seqOf,
      'origins': _from,
      'peers': [for (final p in peers) p.toJson()],
      'removedPeers': _removedPeers.toList(),
    });
    _saving = _saving
        .then((_) async {
          final tmp = File('${_file.path}.tmp');
          await tmp.parent.create(recursive: true);
          await tmp.writeAsString(json, flush: true);
          await tmp.rename(_file.path);
        })
        .catchError((Object e) => debugPrint('Save failed: $e'));
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _syncPeriodic?.cancel();
    _metaSave?.cancel();
    reminders.dispose();
    super.dispose();
  }
}

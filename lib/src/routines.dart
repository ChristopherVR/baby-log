import 'models.dart';

/// Stable identity for records written before multiple babies were supported.
const defaultBabyId = 'default-baby';

/// An actual activity, independent of its repeating schedule. Names are kept
/// as snapshots so renaming or deleting a routine preserves its history.
class RoutineCompletion implements Syncable {
  @override
  final String id;
  final String babyId;
  final String routineId;
  final String routineName;
  final DateTime time;
  final String doneBy;
  final String deviceId;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  RoutineCompletion({
    String? id,
    required this.babyId,
    required this.routineId,
    required this.routineName,
    required this.time,
    required this.doneBy,
    required this.deviceId,
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now();

  RoutineCompletion copyWith({required DateTime updatedAt, bool? deleted}) =>
      RoutineCompletion(
        id: id,
        babyId: babyId,
        routineId: routineId,
        routineName: routineName,
        time: time,
        doneBy: doneBy,
        deviceId: deviceId,
        updatedAt: updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'babyId': babyId,
    'routineId': routineId,
    'routineName': routineName,
    'time': time.millisecondsSinceEpoch,
    'doneBy': doneBy,
    'deviceId': deviceId,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  static RoutineCompletion? fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String ||
        j['babyId'] is! String ||
        j['routineId'] is! String ||
        j['routineName'] is! String ||
        j['time'] is! num ||
        j['doneBy'] is! String ||
        (j['doneBy'] as String).trim().isEmpty ||
        j['deviceId'] is! String) {
      return null;
    }
    return RoutineCompletion(
      id: j['id'],
      babyId: j['babyId'],
      routineId: j['routineId'],
      routineName: j['routineName'],
      time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num).toInt()),
      doneBy: j['doneBy'],
      deviceId: j['deviceId'],
      deleted: j['deleted'] == true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class BabyProfile implements Syncable {
  @override
  final String id;
  final String name;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  BabyProfile({
    String? id,
    required this.name,
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now();

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  static BabyProfile? fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String || j['name'] is! String) return null;
    return BabyProfile(
      id: j['id'],
      name: j['name'],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      deleted: j['deleted'] == true,
    );
  }
}

class Routine implements Syncable {
  @override
  final String id;
  final String babyId;
  final String name;
  final String notes;
  final int minutes;

  /// ISO weekdays: Monday = 1, Sunday = 7.
  final List<int> weekdays;
  final bool enabled;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Routine({
    String? id,
    required this.babyId,
    required this.name,
    this.notes = '',
    this.minutes = 18 * 60,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       weekdays = List.unmodifiable(weekdays.toSet().toList()..sort()),
       updatedAt = updatedAt ?? DateTime.now();

  DateTime? nextAt(DateTime now) {
    if (!enabled || deleted || weekdays.isEmpty) return null;
    for (var offset = 0; offset <= 7; offset++) {
      final at = DateTime(
        now.year,
        now.month,
        now.day + offset,
        minutes ~/ 60,
        minutes % 60,
      );
      if (weekdays.contains(at.weekday) && !at.isBefore(now)) return at;
    }
    return null;
  }

  Routine copyWith({bool? enabled, bool? deleted, DateTime? updatedAt}) =>
      Routine(
        id: id,
        babyId: babyId,
        name: name,
        notes: notes,
        minutes: minutes,
        weekdays: weekdays,
        enabled: enabled ?? this.enabled,
        deleted: deleted ?? this.deleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'babyId': babyId,
    'name': name,
    'notes': notes,
    'minutes': minutes,
    'weekdays': weekdays,
    'enabled': enabled,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  static Routine? fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String || j['babyId'] is! String || j['name'] is! String) {
      return null;
    }
    final minutes = (j['minutes'] as num?)?.toInt() ?? -1;
    final days = (j['weekdays'] as List? ?? [])
        .whereType<int>()
        .toSet()
        .toList();
    if (minutes < 0 ||
        minutes >= 1440 ||
        days.isEmpty ||
        days.any((d) => d < 1 || d > 7)) {
      return null;
    }
    return Routine(
      id: j['id'],
      babyId: j['babyId'],
      name: j['name'],
      notes: j['notes'] as String? ?? '',
      minutes: minutes,
      weekdays: days,
      enabled: j['enabled'] != false,
      deleted: j['deleted'] == true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

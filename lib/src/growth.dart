import 'models.dart';

/// A dated journal entry. Photos are resized before encoding so backups and
/// device sync contain the actual image, never a device-specific file path.
class GrowthEntry implements Syncable {
  @override
  final String id;
  final String babyId;
  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final String? photo;
  final String note;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  GrowthEntry({
    String? id,
    required this.babyId,
    required this.date,
    this.weightKg,
    this.heightCm,
    this.photo,
    this.note = '',
    DateTime? updatedAt,
    this.deleted = false,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now();

  GrowthEntry copyWith({required DateTime updatedAt, bool? deleted}) =>
      GrowthEntry(
        id: id,
        babyId: babyId,
        date: date,
        weightKg: weightKg,
        heightCm: heightCm,
        photo: photo,
        note: note,
        updatedAt: updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'babyId': babyId,
    'date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'weightKg': weightKg,
    'heightCm': heightCm,
    'photo': photo,
    'note': note,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  static GrowthEntry? fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String || j['babyId'] is! String) return null;
    final date = DateTime.tryParse(j['date'] as String? ?? '');
    final weight = (j['weightKg'] as num?)?.toDouble();
    final height = (j['heightCm'] as num?)?.toDouble();
    if (date == null ||
        !validMeasurement(weight) ||
        !validMeasurement(height)) {
      return null;
    }
    return GrowthEntry(
      id: j['id'],
      babyId: j['babyId'],
      date: date,
      weightKg: weight,
      heightCm: height,
      photo: j['photo'] as String?,
      note: j['note'] as String? ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      deleted: j['deleted'] == true,
    );
  }
}

bool validMeasurement(double? value) =>
    value == null || (value.isFinite && value > 0);

/// Completed calendar months, including month-end birthdays.
int ageInMonths(DateTime birth, DateTime date) {
  var months = (date.year - birth.year) * 12 + date.month - birth.month;
  final lastDay = DateTime(date.year, date.month + 1, 0).day;
  if (date.day < (birth.day > lastDay ? lastDay : birth.day)) months--;
  return months < 0 ? 0 : months;
}

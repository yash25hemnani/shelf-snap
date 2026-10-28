import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/core/utils/date_format.dart';

enum DatePrecision { year, month, day }

// A date the user may only partly remember: a year, a month and year,
// or a full date. Saved as its earliest moment plus a precision.

class ReadDate {
  final int year;
  final int? month;
  final int? day;

  const ReadDate(this.year, [this.month, this.day])
    : assert(day == null || month != null, 'A day needs its month');

  factory ReadDate.today() {
    final now = DateTime.now();
    return ReadDate(now.year, now.month, now.day);
  }

  DatePrecision get precision => day != null
      ? DatePrecision.day
      : month != null
      ? DatePrecision.month
      : DatePrecision.year;

  // Earliest moment: 1 Jan for a year, the 1st for a month
  DateTime get start => DateTime(year, month ?? 1, day ?? 1);

  // The first moment after this date is over
  DateTime get end => switch (precision) {
    DatePrecision.year => DateTime(year + 1),
    DatePrecision.month => DateTime(year, month! + 1),
    DatePrecision.day => DateTime(year, month!, day! + 1),
  };

  bool get isInFuture => start.isAfter(DateTime.now());

  bool canStartBefore(ReadDate other) => start.isBefore(other.end);

  Timestamp get timestamp => Timestamp.fromDate(start);

  // Rebuilds the date from the two saved fields. A missing precision
  // counts as a full day.
  factory ReadDate.fromStored(Timestamp stamp, String? precision) {
    final d = stamp.toDate();
    final p = DatePrecision.values.asNameMap()[precision] ?? DatePrecision.day;
    return switch (p) {
      DatePrecision.year => ReadDate(d.year),
      DatePrecision.month => ReadDate(d.year, d.month),
      DatePrecision.day => ReadDate(d.year, d.month, d.day),
    };
  }

  // An optional date saved as two fields: [field] and [field]Precision
  static ReadDate? fromMap(Map<String, dynamic> map, String field) {
    final stamp = map[field] as Timestamp?;
    if (stamp == null) return null;

    return ReadDate.fromStored(stamp, map['${field}Precision'] as String?);
  }

  // "2025", "Mar 2025" or "3 Mar 2025"
  String get label => switch (precision) {
    DatePrecision.year => '$year',
    DatePrecision.month => '${monthShort(month!)} $year',
    DatePrecision.day => '$day ${monthShort(month!)} $year',
  };

  // Equal when year, month and day all match, so "nothing changed"
  // checks work on two separate ReadDate objects
  @override
  bool operator ==(Object other) =>
      other is ReadDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

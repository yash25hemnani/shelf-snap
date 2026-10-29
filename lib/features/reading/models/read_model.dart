import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/reading/models/read_date.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

enum ProgressUnit { pages, percent }

// One read of a book: users/{uid}/readingLogs/{readingKey}/reads/{readId}
class ReadModel {
  final String? id; // null until saved
  final String userId; // lets stats query reads across all books
  final BookStatus status; // the same as the log's; never want to read
  final ReadDate? startedAt; // optional
  final ReadDate? endedAt; // null while reading or paused
  final int progressValue;
  final ProgressUnit progressUnit;
  // The book's page count for this read. Follows the log while the read
  // is active, then stays as it was, so editing the log later doesn't
  // change past stats. Null on reads saved before this field existed.
  final int? pageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReadModel({
    this.id,
    required this.userId,
    this.status = BookStatus.reading,
    this.startedAt,
    this.endedAt,
    this.progressValue = 0,
    this.progressUnit = ProgressUnit.pages,
    this.pageCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ReadModel.fromMap(String id, Map<String, dynamic> map) => ReadModel(
    id: id,
    userId: map['uid'] as String,
    status: BookStatus.values.asNameMap()[map['status']] ?? BookStatus.reading,
    startedAt: ReadDate.fromMap(map, 'startedAt'),
    endedAt: ReadDate.fromMap(map, 'endedAt'),
    progressValue: (map['progressValue'] as num?)?.toInt() ?? 0,
    progressUnit:
        ProgressUnit.values.asNameMap()[map['progressUnit']] ??
        ProgressUnit.pages,
    pageCount: (map['pageCount'] as num?)?.toInt(),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'uid': userId,
    'status': status.name,
    'startedAt': startedAt?.timestamp,
    'startedAtPrecision': startedAt?.precision.name,
    'endedAt': endedAt?.timestamp,
    'endedAtPrecision': endedAt?.precision.name,
    'progressValue': progressValue,
    'progressUnit': progressUnit.name,
    'pageCount': pageCount,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'updatedAt': Timestamp.now(),
  };

  // Reading or paused: the read that progress updates go to
  bool get isActive =>
      status == BookStatus.reading || status == BookStatus.paused;

  // Progress as 0–1 for the bar. Null when it can't be worked out:
  // pages typed, but the book has no page count.
  double? fraction(int? pageCount) {
    if (status == BookStatus.finished) return 1;

    return switch (progressUnit) {
      ProgressUnit.percent => (progressValue / 100).clamp(0, 1).toDouble(),
      ProgressUnit.pages =>
        pageCount == null || pageCount == 0
            ? null
            : (progressValue / pageCount).clamp(0, 1).toDouble(),
    };
  }

  // A copy with the given fields changed. Passing null keeps the current
  // value, so use the clear flags to remove a date.
  ReadModel copyWith({
    BookStatus? status,
    ReadDate? startedAt,
    bool clearStartedAt = false,
    ReadDate? endedAt,
    bool clearEndedAt = false,
    int? progressValue,
    ProgressUnit? progressUnit,
    int? pageCount,
  }) {
    return ReadModel(
      id: id,
      userId: userId,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      progressValue: progressValue ?? this.progressValue,
      progressUnit: progressUnit ?? this.progressUnit,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // A copy with new progress as the user typed it: a page, or a percent.
  // Pages stay within the book's page count when it's known.
  ReadModel withProgress(int value, ProgressUnit unit, int? pageCount) {
    if (!isActive) return this;

    // No page count means no upper limit for pages
    final int? max = unit == ProgressUnit.percent ? 100 : pageCount;
    var next = value < 0 ? 0 : value;
    if (max != null && next > max) next = max;

    if (next == progressValue && unit == progressUnit) return this;

    return copyWith(progressValue: next, progressUnit: unit);
  }

  // A copy moved to [next]. Ending sets the finish date to today.
  // Moving an ended read back to reading or paused reopens it: the
  // finish date is cleared and the progress is kept.
  ReadModel withStatus(BookStatus next) {
    // A read is always started or ended; want to read belongs to the log
    if (next == BookStatus.wantToRead || next == status) return this;

    final ending = next == BookStatus.finished || next == BookStatus.dnf;

    return copyWith(
      status: next,
      // Keep the date when switching between finished and DNF
      endedAt: ending ? (endedAt ?? ReadDate.today()) : null,
      clearEndedAt: !ending,
    );
  }

  // A copy with new dates. An active read has no end; an ended read
  // must have one. No future dates, and the start can't follow the end.
  ReadModel withDates(ReadDate? start, ReadDate? end) {
    // Reading or paused: the read isn't over, so it can't have an end
    if (isActive && end != null) return this;

    // Finished or DNF: the end date is required
    if (!isActive && end == null) return this;

    // Neither date can be in the future
    if ((start?.isInFuture ?? false) || (end?.isInFuture ?? false)) {
      return this;
    }

    // The start can't come after the end
    if (start != null && end != null && !start.canStartBefore(end)) {
      return this;
    }

    // Same dates as before, so there's nothing to save
    if (start == startedAt && end == endedAt) return this;

    return copyWith(
      startedAt: start,
      clearStartedAt: start == null,
      endedAt: end,
      clearEndedAt: end == null,
    );
  }
}

import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

// Totals for the stats screen, for one year or all time
class ReadingStats {
  final int finished; // reads marked finished
  final int pagesRead; // page counts of the finished reads
  final int reReads; // finished reads of a book already finished before
  final int dnf; // reads marked did not finish
  final List<int> finishedPerMonth; // 12 counts, January first

  const ReadingStats({
    required this.finished,
    required this.pagesRead,
    required this.reReads,
    required this.dnf,
    required this.finishedPerMonth,
  });

  // All zeros, shown until the stats are worked out
  const ReadingStats.empty()
    : finished = 0,
      pagesRead = 0,
      reReads = 0,
      dnf = 0,
      finishedPerMonth = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  factory ReadingStats.from(
    List<({String readingKey, ReadModel read})> reads,
    List<ReadingLogModel> logs, {
    int? year,
  }) {
    // Older reads have no page count, so fall back to the log's
    final pagesByKey = {for (final log in logs) log.id: log.pageCount};

    // Finished reads, oldest first, so a book's first finish comes
    // before its re-reads
    final finishedReads =
        reads
            .where(
              (r) =>
                  r.read.status == BookStatus.finished &&
                  r.read.endedAt != null,
            )
            .toList()
          ..sort(
            (a, b) => a.read.endedAt!.start.compareTo(b.read.endedAt!.start),
          );

    final seen = <String>{};
    var finished = 0;
    var pages = 0;
    var reReads = 0;
    final perMonth = List.filled(12, 0);

    for (final r in finishedReads) {
      final end = r.read.endedAt!;
      // add() returns false when the book was already finished before
      final isReRead = !seen.add(r.readingKey);

      if (year != null && end.year != year) continue;

      finished++;
      // The read's own count first; older reads fall back to the log's
      pages += r.read.pageCount ?? pagesByKey[r.readingKey] ?? 0;

      if (isReRead) reReads++;
      if (end.month != null) perMonth[end.month! - 1]++;
    }

    final dnf = reads
        .where(
          (r) =>
              r.read.status == BookStatus.dnf &&
              (year == null || r.read.endedAt?.year == year),
        )
        .length;

    return ReadingStats(
      finished: finished,
      pagesRead: pages,
      reReads: reReads,
      dnf: dnf,
      finishedPerMonth: perMonth,
    );
  }
}

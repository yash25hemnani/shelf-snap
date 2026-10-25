import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

enum BookStatus { wantToRead, reading, paused, finished, dnf }

extension BookStatusLabel on BookStatus {
  String get label => switch (this) {
    BookStatus.wantToRead => 'Want to read',
    BookStatus.reading => 'Reading',
    BookStatus.paused => 'Paused',
    BookStatus.finished => 'Finished',
    BookStatus.dnf => 'Did not finish',
  };
}

class PastRead {
  final DateTime startedAt;
  final DateTime endedAt;
  final BookStatus bookStatus;
  final double progress;

  const PastRead({
    required this.startedAt,
    required this.endedAt,
    required this.bookStatus,
    required this.progress,
  });

  factory PastRead.fromMap(Map<String, dynamic> map) => PastRead(
    startedAt: (map['startedAt'] as Timestamp).toDate(),
    endedAt: (map['endedAt'] as Timestamp).toDate(),
    bookStatus:
        BookStatus.values.asNameMap()[map['bookStatus']] ?? BookStatus.finished,
    progress: (map['progress'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': Timestamp.fromDate(endedAt),
    'bookStatus': bookStatus.name,
    'progress': progress,
  };
}

class ReadingLogModel {
  final String? id;
  // Optional link to a library book; null for search books
  final String? bookId;
  final String readingId;
  final String? aliasFor;

  // A copy of the book, so the log works without a library
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final int? pageCount;

  final BookStatus status;
  final DateTime? startedAt; // current read; null until it starts
  final List<PastRead>? pastReads;
  // final List<Session> sessions;
  final DateTime? createdAt; // null until saved
  final DateTime? updatedAt;

  const ReadingLogModel({
    this.id,
    this.bookId,
    required this.readingId,
    this.aliasFor,
    required this.title,
    this.authors = const [],
    this.coverUrl,
    this.pageCount,
    this.status = BookStatus.wantToRead,
    this.startedAt,
    this.pastReads,
    this.createdAt,
    this.updatedAt,
  });

  factory ReadingLogModel.fromMap(String id, Map<String, dynamic> map) =>
      ReadingLogModel(
        id: id,
        bookId: map['bookId'],
        readingId: map['readingId'],
        aliasFor: map['aliasFor'],
        title: map['title'] as String? ?? BookModel.unknownTitle,
        authors: (map['authors'] as List?)?.cast<String>() ?? const [],
        coverUrl: map['coverUrl'] as String?,
        pageCount: (map['pageCount'] as num?)?.toInt(),
        status:
            BookStatus.values.asNameMap()[map['status']] ??
            BookStatus.wantToRead,
        startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
        pastReads: (map['pastReads'] as List? ?? [])
            .map((read) => PastRead.fromMap(read as Map<String, dynamic>))
            .toList(),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
    'readingId': readingId,
    'bookId': bookId,
    'aliasFor': aliasFor,
    'title': title,
    'authors': authors,
    'coverUrl': coverUrl,
    'pageCount': pageCount,
    'status': status.name,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'pastReads': (pastReads ?? []).map((read) => read.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'updatedAt': Timestamp.now(), // every save is an update
  };
}

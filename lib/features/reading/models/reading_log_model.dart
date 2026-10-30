import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';

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

// One book on the user's reading list: users/{uid}/readingLogs/{readingKey}.
// The reads themselves live in the reads/ subcollection.
class ReadingLogModel {
  final String? id; // the readingKey; null until saved
  final String? bookId; // library book id; null for search books

  // A copy of the book, so the log works without a library
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final int? pageCount;

  // The latest read's status, or want to read. Kept on the log so the
  // list can filter by it.
  final BookStatus status;
  // A copy of the latest read, so screens only need the log; null = no read yet
  final ReadModel? latestRead;
  // For the book across all its reads
  final int? rating; // 1–10; null = not rated
  final String? review; // null = no review
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReadingLogModel({
    this.id,
    this.bookId,
    required this.title,
    this.authors = const [],
    this.coverUrl,
    this.pageCount,
    this.status = BookStatus.wantToRead,
    this.latestRead,
    this.rating,
    this.review,
    this.createdAt,
    this.updatedAt,
  });

  factory ReadingLogModel.fromMap(String id, Map<String, dynamic> map) {
    final readId = map['latestReadId'] as String?;
    // Firestore returns nested maps as Map<dynamic, dynamic> on some platforms
    final readMap = (map['latestRead'] as Map?)?.cast<String, dynamic>();

    return ReadingLogModel(
      id: id,
      bookId: map['bookId'] as String?,
      title: map['title'] as String? ?? BookModel.unknownTitle,
      // Firestore returns List<dynamic>, so cast the items
      authors: (map['authors'] as List?)?.cast<String>() ?? const [],
      coverUrl: map['coverUrl'] as String?,
      pageCount: (map['pageCount'] as num?)?.toInt(),
      status:
          BookStatus.values.asNameMap()[map['status']] ?? BookStatus.wantToRead,
      latestRead: readId == null || readMap == null
          ? null
          : ReadModel.fromMap(readId, readMap),
      rating: (map['rating'] as num?)?.toInt(),
      review: map['review'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    // No 'id': it's the doc id, so storing it would duplicate it
    'bookId': bookId,
    'title': title,
    'authors': authors,
    'coverUrl': coverUrl,
    'pageCount': pageCount,
    'status': status.name,
    // The read's own map has no id, so it's saved next to it
    'latestReadId': latestRead?.id,
    'latestRead': latestRead?.toMap(),
    'rating': rating,
    'review': review,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'updatedAt': Timestamp.now(),
    // Worked out on every save, so old logs get tokens on their next write
    'searchTokens': searchTokens,
  };

  // Word prefixes of the title and authors, the same as BookModel's.
  // "Harry Potter" → ha, har, harr, harry, po, pot, ...
  List<String> get searchTokens {
    final text = [
      if (title != BookModel.unknownTitle) title,
      ...authors,
    ].join(' ');

    final tokens = <String>{};
    for (final word in BookModel.sanitizeWords(text)) {
      for (var i = BookModel.searchTokenMin; i <= word.length; i++) {
        tokens.add(word.substring(0, i));
      }
    }
    return tokens.toList();
  }

  // Reading or paused: the latest read is still going
  bool get hasActiveRead =>
      status == BookStatus.reading || status == BookStatus.paused;

  // A copy with the given fields changed. Passing null keeps the current
  // value, so use [clearLatestRead] when the latest read is deleted.
  ReadingLogModel copyWith({
    int? pageCount,
    BookStatus? status,
    ReadModel? latestRead,
    bool clearLatestRead = false,
  }) {
    return ReadingLogModel(
      id: id,
      bookId: bookId,
      title: title,
      authors: authors,
      coverUrl: coverUrl,
      pageCount: pageCount ?? this.pageCount,
      status: status ?? this.status,
      latestRead: clearLatestRead ? null : (latestRead ?? this.latestRead),
      rating: rating,
      review: review,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

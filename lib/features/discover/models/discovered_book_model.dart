import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// A book spotted in Discover mode: users/{uid}/discovered/{readingKey}.
// Keyed by readingKey, so seeing the same book again (any edition) updates
// one doc instead of adding another.
class DiscoveredBookModel {
  // The model returns at most this many genres per book
  static const maxGenres = 2;

  // Rules cap the places list here; a book seen in more places than this
  // would make the whole scan's save fail
  static const maxPlaces = 50;

  final String id; // the readingKey
  final BookModel book;
  final List<Genre> genres; // empty = the model didn't know the book
  final double score; // spine-to-listing match, 0.0–1.0
  final int seenCount;
  final DateTime? lastSeenAt;
  final String? lastPlace; // null = scanned with no place set
  final List<String>
  places; // oldest first, so places.first is where it was first seen

  const DiscoveredBookModel({
    required this.id,
    required this.book,
    this.genres = const [],
    this.score = 0,
    this.seenCount = 1,
    this.lastSeenAt,
    this.lastPlace,
    this.places = const [],
  });

  static List<Genre> _parseGenres(Object? raw) => [
    for (final name in (raw as List?)?.whereType<String>() ?? const <String>[])
      ?Genre.values.asNameMap()[name],
  ];

  // One book from /discover. Null when it has no readingKey (no title or
  // author), since it couldn't be saved or matched again.
  static DiscoveredBookModel? fromApi(Map<String, dynamic> json) {
    final book = BookModel.fromApi(json);
    final readingKey = book.readingKey;
    if (readingKey == null) return null;

    return DiscoveredBookModel(
      id: readingKey,
      book: book,
      genres: _parseGenres(json['genres']),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  // The book's fields are stored flat, in the same shape the API sends
  factory DiscoveredBookModel.fromMap(String id, Map<String, dynamic> map) {
    return DiscoveredBookModel(
      id: id,
      book: BookModel.fromApi(map),
      genres: _parseGenres(map['genres']),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      seenCount: (map['seenCount'] as num?)?.toInt() ?? 1,
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate(),
      lastPlace: map['lastPlace'] as String?,
      places: (map['places'] as List?)?.cast<String>() ?? const [],
    );
  }

  // Plain values only. DiscoverRepository.saveScan swaps seenCount, places
  // and lastSeenAt for increment / arrayUnion / server time when it merges.
  Map<String, dynamic> toMap() => {
    'googleBooksId': book.googleBooksId,
    'workId': book.workId,
    'isbn': book.isbn,
    'title': book.title,
    'subtitle': book.subtitle,
    'authors': book.authors,
    'description': book.description,
    'categories': book.categories,
    'publisher': book.publisher,
    'publishedDate': book.publishedDate,
    'pageCount': book.pageCount,
    'language': book.language,
    'coverUrl': book.coverUrl,
    'source': book.source?.name,
    'genres': genres.map((g) => g.name).toList(),
    'score': score,
    'seenCount': seenCount,
    'lastSeenAt': Timestamp.fromDate(lastSeenAt ?? DateTime.now()),
    'lastPlace': lastPlace,
    'places': places,
  };

  DiscoveredBookModel copyWith({
    List<Genre>? genres,
    int? seenCount,
    DateTime? lastSeenAt,
    String? lastPlace,
    List<String>? places,
  }) {
    return DiscoveredBookModel(
      id: id,
      book: book,
      genres: genres ?? this.genres,
      score: score,
      seenCount: seenCount ?? this.seenCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastPlace: lastPlace ?? this.lastPlace,
      places: places ?? this.places,
    );
  }

  // Where it was first seen; null when every scan had no place
  String? get firstPlace => places.isEmpty ? null : places.first;

  @override
  String toString() =>
      'DiscoveredBookModel("${book.title}", genres: ${genres.map((g) => g.name)}, '
      'place: $lastPlace)';
}

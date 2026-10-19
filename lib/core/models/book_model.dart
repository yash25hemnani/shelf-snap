import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';

/// Which provider the book details came from.
enum BookSource { google, openlibrary }

/// One edition of a book. Mirrors the backend's `BookDetails`, plus the
/// fields that only exist once the book is saved (id, readingId,
/// libraryIds, addedAt, noOfCopies).
class BookModel {
  // Null until the book is saved.
  final String? id;
  final String? readingId; // shared by every edition of the same title
  final List<String> libraryIds;
  final DateTime? addedAt;
  final int noOfCopies; // physical copies of this edition

  // Provider ids, kept as matching hints.
  final String? googleBooksId;
  final String? workId; // Open Library work, without the "/works/" prefix
  final String? isbn; // always ISBN-13

  // The book.
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? description;
  final List<String> categories;

  // The edition.
  final String? publisher;
  final String? publishedDate; // "2001", "2001-09" or "2001-09-14"
  final int? pageCount;
  final String? language; // ISO 639-1
  final String? coverUrl;

  final BookSource? source;

  /// Placeholder when the provider sends no title.
  static const unknownTitle = 'Unknown Title';

  const BookModel({
    this.id,
    this.readingId,
    this.libraryIds = const [],
    this.addedAt,
    this.noOfCopies = 1,
    this.googleBooksId,
    this.workId,
    this.isbn,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.description,
    this.categories = const [],
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.language,
    this.coverUrl,
    this.source,
  });

  /// One book from /search-books, /isbn-search or /identify-books.
  factory BookModel.fromApi(Map<String, dynamic> json) => BookModel(
    googleBooksId: json['googleBooksId'] as String?,
    workId: json['workId'] as String?,
    isbn: json['isbn'] as String?,
    title: json['title'] as String? ?? unknownTitle,
    subtitle: json['subtitle'] as String?,
    authors: (json['authors'] as List?)?.cast<String>() ?? const [],
    description: json['description'] as String?,
    categories: (json['categories'] as List?)?.cast<String>() ?? const [],
    publisher: json['publisher'] as String?,
    publishedDate: json['publishedDate'] as String?,
    pageCount: (json['pageCount'] as num?)?.toInt(),
    language: json['language'] as String?,
    coverUrl: json['coverUrl'] as String?,
    source: BookSource.values.asNameMap()[json['source']],
  );

  /// A saved doc is the API shape plus our own fields.
  factory BookModel.fromMap(String id, Map<String, dynamic> map) =>
      BookModel.fromApi(map).copyWith(
        id: id,
        readingId: map['readingId'] as String?,
        libraryIds: (map['libraryIds'] as List?)?.cast<String>(),
        addedAt: (map['addedAt'] as Timestamp?)?.toDate(),
        noOfCopies: (map['noOfCopies'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
    'readingId': readingId,
    'libraryIds': libraryIds,
    'addedAt': Timestamp.fromDate(addedAt ?? DateTime.now()),
    'noOfCopies': noOfCopies,
    'googleBooksId': googleBooksId,
    'workId': workId,
    'isbn': isbn,
    'title': title,
    'subtitle': subtitle,
    'authors': authors,
    'description': description,
    'categories': categories,
    'publisher': publisher,
    'publishedDate': publishedDate,
    'pageCount': pageCount,
    'language': language,
    'coverUrl': coverUrl,
    'source': source?.name,
  };

  /// Only our own fields change; the book facts come from the provider.
  BookModel copyWith({
    String? id,
    String? readingId,
    List<String>? libraryIds,
    DateTime? addedAt,
    int? noOfCopies,
  }) => BookModel(
    id: id ?? this.id,
    readingId: readingId ?? this.readingId,
    libraryIds: libraryIds ?? this.libraryIds,
    addedAt: addedAt ?? this.addedAt,
    noOfCopies: noOfCopies ?? this.noOfCopies,
    googleBooksId: googleBooksId,
    workId: workId,
    isbn: isbn,
    title: title,
    subtitle: subtitle,
    authors: authors,
    description: description,
    categories: categories,
    publisher: publisher,
    publishedDate: publishedDate,
    pageCount: pageCount,
    language: language,
    coverUrl: coverUrl,
    source: source,
  );

  /// "A, B" for display; null when there are no authors.
  String? get authorLine => authors.isEmpty ? null : authors.join(', ');

  /// Default reading log id: "title_firstauthor", shared by every edition.
  /// Null when the title or the first author is missing.
  String? get readingKey {
    if (title == unknownTitle || authors.isEmpty) return null;

    final titlePart = normalize(title);
    final authorPart = normalize(authors.first);
    if (titlePart.isEmpty || authorPart.isEmpty) return null;

    return '${titlePart}_$authorPart';
  }

  /// Squishes a title or author into a matching key part:
  /// "The Hobbit (Penguin Classics)" → "hobbit".
  /// Text after a colon is kept on purpose: it often tells books in a
  /// series apart ("Percy Jackson & the Olympians: The Lightning Thief").
  static String normalize(String s) {
    var out = removeDiacritics(s.toLowerCase()); // "Misérables" → "miserables"

    out = out.replaceAll(RegExp(r'\(.*?\)|（.*?）'), ''); // drop "(Book 1)"

    out = out.trim().replaceFirst(
      RegExp(r'^(the|a|an)\s+'),
      '',
    ); // drop a leading article

    return out.replaceAll(
      RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true),
      '',
    ); // letters, marks, digits only
  }

  @override
  String toString() =>
      'BookModel(id: $id, readingId: $readingId, title: "$title", '
      'authors: $authors, isbn: $isbn)';
}

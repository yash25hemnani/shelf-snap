import 'package:cloud_firestore/cloud_firestore.dart';

class BookResult {
  final String? id;
  final String title;
  final String? author;
  final String? isbn;
  final String? coverUrl;
  final List<String> genres;
  final DateTime addedAt;

  BookResult({
    this.id,
    required this.title,
    this.author,
    this.isbn,
    this.coverUrl,
    this.genres = const [],
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'isbn': isbn,
    'coverUrl': coverUrl,
    'genres': genres,
    'addedAt': Timestamp.fromDate(addedAt),
  };

  factory BookResult.fromMap(String id, Map<String, dynamic> map) {
    return BookResult(
      id: id,
      title: map['title'] ?? 'Unknown Title',
      author: map['author'],
      isbn: map['isbn'],
      coverUrl: map['coverUrl'],
      genres: List<String>.from(map['genres'] ?? []),
      addedAt: (map['addedAt'] as Timestamp).toDate(),
    );
  }

  @override
  String toString() =>
      'BookResult(id: $id, title: "$title", author: $author, isbn: $isbn, genres: $genres)';
}
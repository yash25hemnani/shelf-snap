import 'package:cloud_firestore/cloud_firestore.dart';

class BookModel {
  final String? id;
  final String title;
  final String? author;
  final String? isbn;
  final String? coverUrl;
  final String? description;
  final String? publishedDate;
  final int? pageCount;
  final DateTime addedAt;

  BookModel({
    this.id,
    required this.title,
    this.author,
    this.isbn,
    this.coverUrl,
    this.description,
    this.publishedDate,
    this.pageCount,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'isbn': isbn,
    'coverUrl': coverUrl,
    'addedAt': Timestamp.fromDate(addedAt),
    'description': description,
    'publishedDate': publishedDate,
    'pageCount': pageCount,
  };

  factory BookModel.fromMap(String id, Map<String, dynamic> map) {
    return BookModel(
      id: id,
      title: map['title'] ?? 'Unknown Title',
      author: map['author'],
      isbn: map['isbn'],
      coverUrl: map['coverUrl'],
      addedAt: (map['addedAt'] as Timestamp).toDate(),
      description: map['description'],
      publishedDate: map['publishedDate'],
      pageCount: (map['pageCount'] as num?)?.toInt(),
    );
  }

  @override
  String toString() =>
      'BookModel(id: $id, title: "$title", author: $author, isbn: $isbn)';
}

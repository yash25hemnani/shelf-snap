import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryModel {
  final String? id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String ownerId;
  final int bookCount; // physical books, sum of noOfCopies
  final int uniqueCount; // distinct editions, one per book doc
  final List<String> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  LibraryModel({
    this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.ownerId,
    this.bookCount = 0,
    this.uniqueCount = 0,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'coverUrl': coverUrl,
    'ownerId': ownerId,
    'bookCount': bookCount,
    'uniqueCount': uniqueCount,
    'members': members,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory LibraryModel.fromMap(String id, Map<String, dynamic> map) {
    return LibraryModel(
      id: id,
      name: map['name'] ?? 'Untitled',
      description: map['description'],
      coverUrl: map['coverUrl'],
      ownerId: map['ownerId'] ?? '',
      bookCount: (map['bookCount'] as num?)?.toInt() ?? 0,
      uniqueCount: (map['uniqueCount'] as num?)?.toInt() ?? 0,
      members: List<String>.from(map['members'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
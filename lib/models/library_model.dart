import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryModel {
  final String? id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String ownerId;
  final List<String> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  LibraryModel({
    this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.ownerId,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'coverUrl': coverUrl,
    'ownerId': ownerId,
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
      members: List<String>.from(map['members'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
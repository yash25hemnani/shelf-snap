import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

class LibraryModel {
  final String? id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String ownerId;
  final int bookCount; // physical books, sum of noOfCopies
  final int uniqueCount; // distinct editions, one per book doc
  final List<String> members;
  final String banner; // key in AppColors.libraryBanners
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
    this.banner = AppColors.defaultBanner,
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
    'banner': banner,
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
      // Missing or removed banner names fall back to the default
      banner: AppColors.libraryBanners.containsKey(map['banner'])
          ? map['banner'] as String
          : AppColors.defaultBanner,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  LinearGradient get bannerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.libraryBanners[banner]!,
  );
}

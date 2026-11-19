import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

// Public libraries can be found and opened by anyone signed in; outsiders
// only see their public books. Not called visibility, books have that.
enum LibraryAccess { private, public }

class LibraryModel {
  final String? id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String ownerId;
  final int bookCount; // physical books, sum of noOfCopies
  final int uniqueCount; // distinct editions, one per book doc
  final List<String> members;
  final List<String> editors; // can edit copies; always inside members
  final String banner; // key in AppColors.libraryBanners
  final LibraryAccess access;
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
    this.editors = const [],
    this.banner = AppColors.defaultBanner,
    this.access = LibraryAccess.private,
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
    'editors': editors,
    'banner': banner,
    'access': access.name,
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
      // Libraries made before editors existed: only the owner can edit
      editors: List<String>.from(map['editors'] ?? [map['ownerId'] ?? '']),
      // Missing or removed banner names fall back to the default
      banner: AppColors.libraryBanners.containsKey(map['banner'])
          ? map['banner'] as String
          : AppColors.defaultBanner,
      // Libraries made before access existed stay private
      access:
          LibraryAccess.values.asNameMap()[map['access']] ??
          LibraryAccess.private,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  bool get isPublic => access == LibraryAccess.public;

  ImageProvider get bannerImage =>
      AssetImage(AppColors.libraryBanners[banner]!);

  // True when this user can edit the library's copies. The owner always
  // can, even if the editors list was written without them.
  bool canEdit(String? uid) =>
      uid != null && (uid == ownerId || editors.contains(uid));
}

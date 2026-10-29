import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username; // stored lowercase
  final String name;
  final String email; // stored lowercase
  final String? photoUrl;
  final String? avatarSeed;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.username,
    required this.name,
    required this.email,
    this.photoUrl,
    this.avatarSeed,
    required this.createdAt,
  });

  // uid is the doc id, so it isn't stored as a field
  Map<String, dynamic> toMap() => {
    'username': username,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'avatarSeed': avatarSeed,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final username = map['username'] as String? ?? '';
    final name = map['name'] as String?;

    return UserModel(
      uid: uid,
      username: username,
      // Falls back to the username when no display name is set
      name: (name == null || name.isEmpty) ? username : name,
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      avatarSeed: map['avatarSeed'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // 3–20 characters: lowercase letters, numbers, dots and underscores
  static final usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

  // Returns an error message for the form field, or null when valid
  static String? validateUsername(String? value) {
    final v = value?.trim().toLowerCase() ?? '';
    if (!usernamePattern.hasMatch(v)) {
      return '3–20 characters: letters, numbers, . and _';
    }
    if (v.startsWith('.') || v.endsWith('.') || v.contains('..')) {
      return "Can't start or end with a dot, or use two in a row";
    }
    return null;
  }
}

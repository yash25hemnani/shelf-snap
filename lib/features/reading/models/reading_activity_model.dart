import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType { started, finished }

// One event for the friends feed: users/{uid}/activity/{readId}_{type}.
// Written with the status change and deleted when it's undone, so the
// id comes from the read: saving twice never makes a second item.
class ReadingActivityModel {
  final String id;
  final ActivityType type;
  final String readingKey;
  // A copy of the book, so the feed needs no extra reads
  final String title;
  final String? coverUrl;
  final DateTime at;

  const ReadingActivityModel({
    required this.id,
    required this.type,
    required this.readingKey,
    required this.title,
    this.coverUrl,
    required this.at,
  });

  static String idFor(String readId, ActivityType type) =>
      '${readId}_${type.name}';

  factory ReadingActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return ReadingActivityModel(
      id: id,
      type:
          ActivityType.values.asNameMap()[map['type']] ?? ActivityType.started,
      readingKey: map['readingKey'] as String? ?? '',
      title: map['title'] as String? ?? '',
      coverUrl: map['coverUrl'] as String?,
      // Null only for a moment on the writer's phone, before the server time
      at: (map['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // The rules require 'at' to be the server's time
  Map<String, dynamic> toMap() => {
    'type': type.name,
    'readingKey': readingKey,
    'title': title,
    'coverUrl': coverUrl,
    'at': FieldValue.serverTimestamp(),
  };
}

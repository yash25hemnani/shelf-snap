import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus { pending, accepted }

class FriendshipModel {
  final String id; // sorted uidA_uidB
  final List<String> uids; // both uids, for arrayContains queries
  final String fromUid;
  final String fromUsername; // copied in, so lists need no extra user reads
  final String toUid;
  final String toUsername;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt; // null until accepted

  const FriendshipModel({
    required this.id,
    required this.uids,
    required this.fromUid,
    required this.fromUsername,
    required this.toUid,
    required this.toUsername,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  // Sorted so both people get the same doc id
  static String idFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  bool get isPending => status == FriendshipStatus.pending;

  // A request someone sent to me, which I can accept or decline
  bool isIncoming(String me) => isPending && toUid == me;

  // The friend's side of the pair, whichever way the request went
  String otherUid(String me) => fromUid == me ? toUid : fromUid;

  String otherUsername(String me) => fromUid == me ? toUsername : fromUsername;

  // id is the doc id, so it isn't stored as a field
  Map<String, dynamic> toMap() => {
    'uids': uids,
    'fromUid': fromUid,
    'fromUsername': fromUsername,
    'toUid': toUid,
    'toUsername': toUsername,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'respondedAt': respondedAt == null
        ? null
        : Timestamp.fromDate(respondedAt!),
  };

  factory FriendshipModel.fromMap(String id, Map<String, dynamic> map) {
    return FriendshipModel(
      id: id,
      uids: List<String>.from(map['uids'] ?? const []),
      fromUid: map['fromUid'] as String? ?? '',
      fromUsername: map['fromUsername'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      toUsername: map['toUsername'] as String? ?? '',
      // Unknown or missing values read as pending
      status:
          FriendshipStatus.values.asNameMap()[map['status']] ??
          FriendshipStatus.pending,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  FriendshipModel copyWith({
    FriendshipStatus? status,
    String? fromUsername,
    String? toUsername,
    DateTime? respondedAt,
  }) {
    return FriendshipModel(
      id: id,
      uids: uids,
      fromUid: fromUid,
      fromUsername: fromUsername ?? this.fromUsername,
      toUid: toUid,
      toUsername: toUsername ?? this.toUsername,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

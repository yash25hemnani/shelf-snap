import 'package:cloud_firestore/cloud_firestore.dart';

enum InviteStatus { pending, accepted, declined }

class InviteModel {
  final String id; // libraryId_toUid
  final String libraryId;
  final String libraryName; // copied in, the invitee can't read the library yet
  final String fromUid;
  final String fromUsername;
  final String toUid;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt; // null until accepted or declined

  const InviteModel({
    required this.id,
    required this.libraryId,
    required this.libraryName,
    required this.fromUid,
    required this.fromUsername,
    required this.toUid,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  // Fixed doc id, so there's one invite per person per library
  static String idFor(String libraryId, String toUid) => '${libraryId}_$toUid';

  bool get isPending => status == InviteStatus.pending;

  // id is the doc id, so it isn't stored as a field
  Map<String, dynamic> toMap() => {
    'libraryId': libraryId,
    'libraryName': libraryName,
    'fromUid': fromUid,
    'fromUsername': fromUsername,
    'toUid': toUid,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'respondedAt': respondedAt == null
        ? null
        : Timestamp.fromDate(respondedAt!),
  };

  factory InviteModel.fromMap(String id, Map<String, dynamic> map) {
    final statusName = map['status'] as String?;

    return InviteModel(
      id: id,
      libraryId: map['libraryId'] as String? ?? '',
      libraryName: map['libraryName'] as String? ?? '',
      fromUid: map['fromUid'] as String? ?? '',
      fromUsername: map['fromUsername'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      // Unknown or missing values read as pending
      status: InviteStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => InviteStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}

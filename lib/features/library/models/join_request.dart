import 'package:cloud_firestore/cloud_firestore.dart';

// Someone asking to join a public library, at
// libraries/{libraryId}/joinRequests/{uid}. ownerId and libraryName are
// copied in so the owner's notifications don't need to read each library.
class JoinRequest {
  final String uid; // the requester, also the doc id
  final String libraryId; // from the doc path, not stored as a field
  final String username;
  final String ownerId;
  final String libraryName;
  final DateTime createdAt;

  const JoinRequest({
    required this.uid,
    required this.libraryId,
    required this.username,
    required this.ownerId,
    required this.libraryName,
    required this.createdAt,
  });

  // createdAt is left out: the repository writes the server time, which
  // the rules check against request.time
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'username': username,
    'ownerId': ownerId,
    'libraryName': libraryName,
  };

  factory JoinRequest.fromMap(
    String id,
    String libraryId,
    Map<String, dynamic> map,
  ) {
    return JoinRequest(
      uid: id,
      libraryId: libraryId,
      username: map['username'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      libraryName: map['libraryName'] as String? ?? '',
      // Null for a moment while the server time is pending
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Built from a snapshot, so the library id comes from the parent path
  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      JoinRequest.fromMap(doc.id, doc.reference.parent.parent!.id, doc.data()!);
}

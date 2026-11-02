import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

class FriendshipRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.collection('friendships').doc(id);

  // A transaction, not set(), so an existing friendship or a request the
  // other person already sent is never overwritten
  Future<void> sendRequest({
    required UserModel from,
    required UserModel to,
  }) async {
    if (from.uid == to.uid) {
      throw Exception("You can't add yourself as a friend");
    }

    final id = FriendshipModel.idFor(from.uid, to.uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(id));

      if (snap.exists) {
        final existing = FriendshipModel.fromMap(snap.id, snap.data()!);
        if (!existing.isPending) {
          throw Exception('You are already friends with ${to.username}');
        }
        if (existing.isIncoming(from.uid)) {
          throw Exception('${to.username} already sent you a request');
        }
        throw Exception('You already sent ${to.username} a request');
      }

      final friendship = FriendshipModel(
        id: id,
        uids: [from.uid, to.uid],
        fromUid: from.uid,
        fromUsername: from.username,
        toUid: to.uid,
        toUsername: to.username,
        status: FriendshipStatus.pending,
        createdAt: DateTime.now(),
      );

      tx.set(_ref(id), friendship.toMap());
    });
  }

  // One listener for friends, incoming and outgoing; providers split it
  Stream<List<FriendshipModel>> watchAll(String uid) {
    return _db
        .collection('friendships')
        .where('uids', arrayContains: uid)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FriendshipModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> accept(FriendshipModel f) {
    return _ref(f.id).update({
      'status': FriendshipStatus.accepted.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Decline, cancel and unfriend all delete, so a new request is never blocked
  Future<void> remove(FriendshipModel f) => _ref(f.id).delete();
}

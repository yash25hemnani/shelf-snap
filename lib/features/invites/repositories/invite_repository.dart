import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

class InviteRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> sendInvite({
    required LibraryModel library,
    required UserModel from,
    required UserModel to,
  }) async {
    final id = InviteModel.idFor(library.id!, to.uid);

    final invite = InviteModel(
      id: id,
      libraryId: library.id!,
      libraryName: library.name,
      fromUid: from.uid,
      fromUsername: from.username,
      toUid: to.uid,
      status: InviteStatus.pending,
      createdAt: DateTime.now(),
    );

    await _db.collection('invites').doc(id).set(invite.toMap());
  }

  Stream<List<InviteModel>> watchIncoming(String uid) {
    return _db
        .collection('invites')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => InviteModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> accept(InviteModel invite) async {
    final batch = _db.batch();
    final libraryRef = _db.collection('libraries').doc(invite.libraryId);
    final inviteRef = _db.collection('invites').doc(invite.id);

    batch.update(inviteRef, {
      'status': InviteStatus.accepted.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
    batch.update(libraryRef, {
      'members': FieldValue.arrayUnion([invite.toUid]),
    });

    await batch.commit();
  }

  // Only the invite changes, so a plain update is enough
  Future<void> decline(InviteModel invite) {
    return _db.collection('invites').doc(invite.id).update({
      'status': InviteStatus.declined.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

class UsernameTakenException implements Exception {}

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> claimUsername(UserModel user) async {
    final usernameRef = _db.collection('usernames').doc(user.username);
    final userRef = _db.collection('users').doc(user.uid);

    if (UserModel.validateUsername(user.username) != null) {
      throw ArgumentError('Invalid username: ${user.username}');
    }

    await _db.runTransaction((tx) async {
      final taken = await tx.get(usernameRef);

      if (taken.exists) throw UsernameTakenException();

      tx.set(usernameRef, {'uid': user.uid});
      tx.set(userRef, user.toMap());
    });
  }

  Future<void> updateProfile(
    UserModel user, {
    required String username,
    required String avatarSeed,
  }) async {
    final newUsernameRef = _db.collection('usernames').doc(username);
    final oldUsernameRef = _db.collection('usernames').doc(user.username);

    final userRef = _db.collection('users').doc(user.uid);

    if (UserModel.validateUsername(username) != null) {
      throw ArgumentError('Invalid username: $username');
    }

    await _db.runTransaction((tx) async {
      // Only move the reservation when the name changed
      if (username != user.username) {
        final taken = await tx.get(newUsernameRef);
        if (taken.exists) throw UsernameTakenException();

        tx.delete(oldUsernameRef);
        tx.set(newUsernameRef, {'uid': user.uid});
      }

      tx.update(userRef, {'username': username, 'avatarSeed': avatarSeed});
    });
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;

      return UserModel.fromMap(uid, snap.data()!);
    });
  }

  Stream<List<UserModel>> watchUsers(List<String> uids) {
    if (uids.isEmpty) return Stream.value([]);

    return _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList(),
        );
  }

  // Users whose username starts with prefix, A–Z, excluding the signed-in user
  Future<List<UserModel>> searchUsers(String prefix) async {
    final uid = AuthService().currentUser?.uid;
    final q = prefix.trim().toLowerCase();
    if (q.isEmpty) return [];

    //  sorts after every normal character, so this range is "starts with q"
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '$q\uf8ff')
        .orderBy('username')
        .limit(10)
        .get();

    return snap.docs
        .where((doc) => doc.id != uid)
        .map((doc) => UserModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}

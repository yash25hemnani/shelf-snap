import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/repositories/friendship_repository.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

final friendshipRepositoryProvider = Provider((ref) => FriendshipRepository());

// Not autoDispose: Profile, Home and the Friends screen share one listener
final friendshipsProvider = StreamProvider<List<FriendshipModel>>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);

  return ref.watch(friendshipRepositoryProvider).watchAll(uid);
});

// The three lists below split friendshipsProvider, so they cost no extra reads

final friendsProvider = Provider<AsyncValue<List<FriendshipModel>>>((ref) {
  return ref
      .watch(friendshipsProvider)
      .whenData((all) => all.where((f) => !f.isPending).toList());
});

// Requests other people sent me, which I can accept or decline
final incomingRequestsProvider = Provider<AsyncValue<List<FriendshipModel>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  return ref
      .watch(friendshipsProvider)
      .whenData(
        (all) => uid == null
            ? const []
            : all.where((f) => f.isIncoming(uid)).toList(),
      );
});

// Another person's profile, for names and avatars. userProfileProvider
// only loads the signed-in user, so friends need their own.
final otherUserProvider = StreamProvider.autoDispose.family<UserModel?, String>(
  (ref, uid) {
    return ref.watch(userRepositoryProvider).watchUser(uid);
  },
);

// Requests I sent that haven't been answered yet
final sentRequestsProvider = Provider<AsyncValue<List<FriendshipModel>>>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  return ref
      .watch(friendshipsProvider)
      .whenData(
        (all) => uid == null
            ? const []
            : all.where((f) => f.isPending && f.fromUid == uid).toList(),
      );
});

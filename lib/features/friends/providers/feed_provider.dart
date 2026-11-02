import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/friends/models/feed_item.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/reading/models/reading_activity_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';

// Rows on the Friends card
const feedSize = 8;
// Feed items read per friend: enough to fill the card from one busy friend
const _perFriend = 3;
// Only the newest friends are asked, so Home reads at most 30 × 3 docs
const _friendCap = 30;

// One friend's newest started and finished items, live
final friendActivityProvider = StreamProvider.autoDispose
    .family<List<ReadingActivityModel>, String>((ref, friendUid) {
      return ref
          .watch(readingLogRepositoryProvider)
          .watchActivity(friendUid, limit: _perFriend);
    });

// The Friends card: every friend's activity plus "became friends",
// newest first. Built from friendsProvider, so someone unfriended drops
// out straight away. A friend whose items fail to load is skipped.
final friendsFeedProvider = Provider.autoDispose<List<FeedItem>>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return const [];

  final friends = [...?ref.watch(friendsProvider).valueOrNull];
  DateTime since(FriendshipModel f) => f.respondedAt ?? f.createdAt;
  friends.sort((a, b) => since(b).compareTo(since(a)));

  final items = <FeedItem>[];
  for (final f in friends.take(_friendCap)) {
    final friendUid = f.otherUid(uid);
    final username = f.otherUsername(uid);

    items.add(
      FeedItem(
        type: FeedItemType.becameFriends,
        friendship: f,
        friendUid: friendUid,
        username: username,
        at: since(f),
      ),
    );

    final activity = ref.watch(friendActivityProvider(friendUid)).valueOrNull;
    for (final a in activity ?? const <ReadingActivityModel>[]) {
      items.add(
        FeedItem(
          type: a.type == ActivityType.finished
              ? FeedItemType.finished
              : FeedItemType.started,
          friendship: f,
          friendUid: friendUid,
          username: username,
          at: a.at,
          title: a.title,
          coverUrl: a.coverUrl,
        ),
      );
    }
  }

  items.sort((a, b) => b.at.compareTo(a.at));
  return items.take(feedSize).toList();
});

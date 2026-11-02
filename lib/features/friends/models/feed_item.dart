import 'package:shelf_snap/features/friends/models/friendship_model.dart';

enum FeedItemType { started, finished, becameFriends }

// One row on the Friends card. Built in the app from friendships and
// friends' activity, never saved.
class FeedItem {
  final FeedItemType type;
  // Opens the friend's page when the row is tapped
  final FriendshipModel friendship;
  final String friendUid;
  final String username;
  final DateTime at;
  final String? title; // the book; null for became friends
  final String? coverUrl;

  const FeedItem({
    required this.type,
    required this.friendship,
    required this.friendUid,
    required this.username,
    required this.at,
    this.title,
    this.coverUrl,
  });
}

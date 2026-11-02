import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';

enum _FriendAction { unfriend }

// A friend's page. For now the header and Unfriend; their reading
// activity is added below the header in the next step.
class FriendScreen extends ConsumerWidget {
  final FriendshipModel friendship;
  final String myUid;

  const FriendScreen({
    super.key,
    required this.friendship,
    required this.myUid,
  });

  Future<void> _confirmUnfriend(BuildContext context, WidgetRef ref) async {
    final username = friendship.otherUsername(myUid);
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      title: 'Unfriend @$username?',
      message:
          "You'll stop seeing each other's reading. You can send a new "
          'request later.',
      confirmLabel: 'Unfriend',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(friendshipRepositoryProvider).remove(friendship);
      navigator.pop();
      messenger.showMessage('Unfriended @$username');
    } catch (e) {
      debugPrint('unfriend failed: $e');
      messenger.showError("Couldn't unfriend, check your connection");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final friendUid = friendship.otherUid(myUid);
    final username = friendship.otherUsername(myUid);
    final profile = ref.watch(otherUserProvider(friendUid)).valueOrNull;
    final since = friendship.respondedAt ?? friendship.createdAt;

    return Scaffold(
      appBar: AppBar(
        titleTextStyle: theme.textTheme.titleMedium,
        title: Text('@$username'),
        actions: [
          PopupMenuButton<_FriendAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (_) => _confirmUnfriend(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _FriendAction.unfriend,
                child: ListTile(
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Unfriend',
                    style: TextStyle(color: AppColors.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: profile == null
                ? ClayAvatar(seed: friendUid, radius: 40)
                : UserAvatar(user: profile, radius: 40),
          ),
          const SizedBox(height: 12),
          Text(
            profile?.name ?? '@$username',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            '@$username · Friends since ${dayMonth(since)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

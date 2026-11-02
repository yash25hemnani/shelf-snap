import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/friends/screens/friend_screen.dart';
import 'package:shelf_snap/features/friends/sheets/add_friend_sheet.dart';
import 'package:shelf_snap/features/friends/widgets/friend_request_tile.dart';
import 'package:shelf_snap/features/friends/widgets/person_tile.dart';

// Incoming requests, sent requests and the friends list, each section
// shown only when it has something in it
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  void _openFriend(BuildContext context, FriendshipModel f, String myUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendScreen(friendship: f, myUid: myUid),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myUid = ref.watch(currentUidProvider).valueOrNull ?? '';
    final friendsAsync = ref.watch(friendsProvider);
    final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
    final sent = ref.watch(sentRequestsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        titleTextStyle: theme.textTheme.titleMedium,
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add a friend',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => AddFriendSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('friends failed: $e');
          return const Center(child: Text("Couldn't load friends"));
        },
        data: (friends) {
          if (friends.isEmpty && incoming.isEmpty && sent.isEmpty) {
            return _EmptyState(onAdd: () => AddFriendSheet.show(context));
          }

          // Alphabetical, so a friend is easy to find in a long list
          final sorted = [...friends]
            ..sort(
              (a, b) =>
                  a.otherUsername(myUid).compareTo(b.otherUsername(myUid)),
            );

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
            children: [
              if (incoming.isNotEmpty) ...[
                _heading(context, 'Requests'),
                for (final r in incoming)
                  FriendRequestTile(
                    key: ValueKey(r.id),
                    request: r,
                    myUid: myUid,
                  ),
              ],
              if (sent.isNotEmpty) ...[
                _heading(context, 'Sent'),
                for (final r in sent)
                  FriendRequestTile(
                    key: ValueKey(r.id),
                    request: r,
                    myUid: myUid,
                  ),
              ],
              _heading(context, 'Friends · ${friends.length}'),
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'No friends yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final f in sorted)
                PersonTile(
                  key: ValueKey(f.id),
                  uid: f.otherUid(myUid),
                  username: f.otherUsername(myUid),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.hint,
                  ),
                  onTap: () => _openFriend(context, f, myUid),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AppColors.hint,
            ),
            const SizedBox(height: 12),
            Text('No friends yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Find people by their @username and send a request.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add a friend'),
            ),
          ],
        ),
      ),
    );
  }
}

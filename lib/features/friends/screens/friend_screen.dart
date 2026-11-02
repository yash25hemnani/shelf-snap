import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friend_reading_provider.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/reading/widgets/reading_log_tile.dart';

enum _FriendAction { unfriend }

// A friend's page: who they are, this year's numbers, what they're
// reading and what they've finished. Never their ratings, reviews or
// want-to-read list; the rules block those.
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
          const SizedBox(height: 24),
          _YearStats(friendUid: friendUid),
          const SizedBox(height: 24),
          _CurrentSection(friendUid: friendUid),
          const SizedBox(height: 24),
          _EndedSection(friendUid: friendUid),
        ],
      ),
    );
  }
}

// Section heading on the friend's page
class _Heading extends StatelessWidget {
  final String title;

  const _Heading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

// Grey one-line text for empty and failed sections
class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    );
  }
}

// Books finished this year and pages read, side by side
class _YearStats extends ConsumerWidget {
  final String friendUid;

  const _YearStats({required this.friendUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(friendYearStatsProvider(friendUid));
    // Dashes while loading or when it failed, so the layout doesn't jump
    final finished = stats.valueOrNull?.finished;
    final pages = stats.valueOrNull?.pagesRead;
    final year = DateTime.now().year;

    return Row(
      children: [
        _StatBox(
          icon: Icons.check_circle_outline_rounded,
          value: finished == null ? '–' : '$finished',
          label: 'finished in $year',
        ),
        const SizedBox(width: 8),
        _StatBox(
          icon: Icons.description_outlined,
          value: pages == null ? '–' : '$pages',
          label: 'pages read',
        ),
      ],
    );
  }
}

// One number in a bordered card, half the row wide
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// What the friend is reading or has paused
class _CurrentSection extends ConsumerWidget {
  final String friendUid;

  const _CurrentSection({required this.friendUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(friendCurrentLogsProvider(friendUid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('Currently reading'),
        ...logs.when(
          loading: () => const [_Note('Loading…')],
          error: (e, _) {
            debugPrint('friend current logs failed: $e');
            return const [_Note("Couldn't load their reading")];
          },
          data: (list) => list.isEmpty
              ? const [_Note('Not reading anything right now')]
              : [
                  for (final log in list) ...[
                    ReadingLogTile(log: log),
                    const SizedBox(height: 8),
                  ],
                ],
        ),
      ],
    );
  }
}

// Finished and DNF books, newest first, with Load more
class _EndedSection extends ConsumerWidget {
  final String friendUid;

  const _EndedSection({required this.friendUid});

  void _loadMore(WidgetRef ref) {
    final limit = ref.read(friendEndedLimitProvider(friendUid).notifier);
    limit.state += friendEndedPageSize;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(friendEndedLogsProvider(friendUid));
    final limit = ref.watch(friendEndedLimitProvider(friendUid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('Finished and stopped'),
        ...logs.when(
          // Keeps the loaded books on screen while Load more fetches
          skipLoadingOnReload: true,
          loading: () => const [_Note('Loading…')],
          error: (e, _) {
            debugPrint('friend ended logs failed: $e');
            return const [_Note("Couldn't load their finished books")];
          },
          data: (list) => list.isEmpty
              ? const [_Note('No finished books yet')]
              : [
                  for (final log in list) ...[
                    ReadingLogTile(log: log),
                    const SizedBox(height: 8),
                  ],
                  // A full page means there may be more
                  if (list.length >= limit)
                    TextButton(
                      onPressed: () => _loadMore(ref),
                      child: const Text('Load more'),
                    ),
                ],
        ),
      ],
    );
  }
}

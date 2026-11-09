import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/discover/screens/discovered_screen.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/friends/screens/friends_screen.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/screens/loans_screen.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/profile/screens/edit_profile_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_logs_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_stats_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // AuthGate sees the signed-out user and swaps to the login screen
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.logout_rounded,
      title: 'Sign out?',
      message: 'You can sign back in any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );

    if (confirmed) await AuthService().signOut();
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = AuthService().currentUser;

    // AuthGate handles login; build must not navigate
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final profile = ref.watch(userProfileProvider(user.uid)).valueOrNull;
    final libraries = ref.watch(userLibrariesProvider(user.uid)).valueOrNull;
    // Requests in the user's libraries still waiting for an answer
    final waiting =
        ref
            .watch(loansProvider(LoanDirection.lent))
            .valueOrNull
            ?.where((l) => l.status == LoanStatus.requested)
            .length ??
        0;

    // Both come from the one friendships listener, so no extra reads
    final friendCount = ref.watch(friendsProvider).valueOrNull?.length;
    final incomingCount =
        ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleTextStyle: theme.textTheme.headlineMedium,
        title: const Text('Profile'),
        actions: [
          if (profile != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  _push(context, EditProfileScreen(profile: profile)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        // Extra bottom space so the last item clears the navbar
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Centred avatar with the name and @username below it
          if (profile != null)
            Column(
              children: [
                UserAvatar(user: profile, radius: 40),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          _StatsCard(
            libraries: libraries?.length,
            // Libraries store their own counts, so no extra reads
            books: libraries?.fold<int>(
              0,
              (sum, library) => sum + library.bookCount,
            ),
            friends: friendCount,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _Tile(
                color: AppColors.primary,
                icon: Icons.auto_stories_rounded,
                title: 'Reading logs',
                subtitle: 'Your books',
                onTap: () => _push(context, const ReadingLogsScreen()),
              ),
              const SizedBox(width: 12),
              _Tile(
                color: AppColors.accent,
                icon: Icons.insights_rounded,
                title: 'Stats',
                subtitle: 'This year',
                onTap: () => _push(context, const ReadingStatsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Tile(
                color: AppColors.secondary,
                icon: Icons.handshake_rounded,
                title: 'Loans',
                subtitle: waiting > 0 ? '$waiting waiting' : 'Lent & borrowed',
                badge: waiting,
                onTap: () => _push(context, const LoansScreen()),
              ),
              const SizedBox(width: 12),
              _Tile(
                color: AppColors.primaryDark,
                icon: Icons.people_alt_rounded,
                title: 'Friends',
                subtitle: incomingCount > 0
                    ? '$incomingCount new request${incomingCount == 1 ? '' : 's'}'
                    : friendCount == null
                    ? ' '
                    : '$friendCount friend${friendCount == 1 ? '' : 's'}',
                badge: incomingCount,
                onTap: () => _push(context, const FriendsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Discover scans are saved here; without this row they were only
          // reachable from the scanner
          _Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(
                Icons.collections_bookmark_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Discovered'),
              subtitle: const Text('Books you spotted with Discover'),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.hint,
              ),
              onTap: () => _push(context, const DiscoveredScreen()),
            ),
          ),
          const SizedBox(height: 16),

          // Settings stays hidden until it exists; a "Coming soon" row
          // made the app look unfinished
          _Card(
            child: InkWell(
              onTap: () => _confirmSignOut(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Sign out',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// White rounded card with a light border
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias, // keeps row ripples inside the corners
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// Libraries, Books and Friends in one card with thin dividers; null shows "–"
class _StatsCard extends StatelessWidget {
  final int? libraries;
  final int? books;
  final int? friends;

  const _StatsCard({this.libraries, this.books, this.friends});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget stat(int? value, String label) => Expanded(
      child: Column(
        children: [
          Text(value?.toString() ?? '–', style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    const divider = VerticalDivider(
      width: 1,
      indent: 4,
      endIndent: 4,
      color: AppColors.border,
    );

    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        // Lets the dividers stretch to the height of the numbers
        child: IntrinsicHeight(
          child: Row(
            children: [
              stat(libraries, 'Libraries'),
              divider,
              stat(books, 'Books'),
              divider,
              stat(friends, 'Friends'),
            ],
          ),
        ),
      ),
    );
  }
}

// Solid colour tile: white title and subtitle on the left, a large faded
// icon cut off at the bottom right as a watermark
class _Tile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge; // shown as a white pill when above 0

  const _Tile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias, // clips the watermark and the ripple
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 112,
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  bottom: -16,
                  child: Icon(
                    icon,
                    size: 88,
                    color: AppColors.onPrimary.withValues(alpha: 0.18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (badge > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$badge',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

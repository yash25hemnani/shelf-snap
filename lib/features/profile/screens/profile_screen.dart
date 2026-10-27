import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/reading/screens/reading_logs_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // AuthGate sees the signed-out user and swaps to the login screen
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) await AuthService().signOut();
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showMessage('Coming soon');
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
    final librariesAsync = ref.watch(userLibrariesProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleTextStyle: theme.textTheme.headlineMedium,
        title: const Text('Profile'),
      ),
      body: ListView(
        // Extra bottom space so the last item clears the navbar
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Avatar with the name and @username beside it
          SizedBox(
            height: 64,
            child: profile == null
                ? null
                : Row(
                    children: [
                      UserAvatar(user: profile, radius: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Libraries, Books and Friends in one card
          _Card(
            padding: const EdgeInsets.symmetric(vertical: 16),
            // Lets the dividers stretch to the height of the stats
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Stat(
                    value: librariesAsync.valueOrNull?.length,
                    label: 'Libraries',
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  _Stat(
                    // Libraries store their own counts, so no extra reads
                    value: librariesAsync.valueOrNull?.fold<int>(
                      0,
                      (sum, library) => sum + library.bookCount,
                    ),
                    label: 'Books',
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  // Shows "–" until friends exist
                  const _Stat(label: 'Friends'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _Card(
            child: Column(
              children: [
                // Opens the reading list until the stats screen exists
                _MenuRow(
                  icon: Icons.insights_rounded,
                  label: 'Reading Stats',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReadingLogsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 68, color: AppColors.border),
                _MenuRow(
                  icon: Icons.people_alt_outlined,
                  label: 'Friends',
                  onTap: () => _comingSoon(context),
                ),
                const Divider(height: 1, indent: 68, color: AppColors.border),
                _MenuRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _comingSoon(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(52), // full width
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
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias, // keeps row ripples inside the corners
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// One number over its label; null shows "–"
class _Stat extends StatelessWidget {
  final int? value;
  final String label;

  const _Stat({this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
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
  }
}

// Icon in a soft square, a label and a chevron
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryDark),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
    );
  }
}

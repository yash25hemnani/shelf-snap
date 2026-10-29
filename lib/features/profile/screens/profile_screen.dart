import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/profile/screens/edit_profile_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_logs_screen.dart';

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
        actions: [
          if (profile != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              ),
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

          // Libraries, Books and Friends, each in its own card
          Row(
            children: [
              _Stat(
                value: librariesAsync.valueOrNull?.length,
                label: 'Libraries',
              ),
              const SizedBox(width: 8),
              _Stat(
                // Libraries store their own counts, so no extra reads
                value: librariesAsync.valueOrNull?.fold<int>(
                  0,
                  (sum, library) => sum + library.bookCount,
                ),
                label: 'Books',
              ),
              const SizedBox(width: 8),
              // Shows "–" until friends exist
              const _Stat(label: 'Friends'),
            ],
          ),
          const SizedBox(height: 24),

          // Opens the reading list until the stats screen exists
          _MenuRow(
            icon: Icons.insights_rounded,
            label: 'Reading Stats',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReadingLogsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.people_alt_outlined,
            label: 'Friends',
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: 16),

          TextButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(
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

// A card with one number over its label; null shows "–"
class _Stat extends StatelessWidget {
  final int? value;
  final String label;

  const _Stat({this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: _Card(
        padding: const EdgeInsets.symmetric(vertical: 32),
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
      ),
    );
  }
}

// Full-width card with an icon in a soft square, a label and a chevron
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
    return _Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.hint,
        ),
      ),
    );
  }
}

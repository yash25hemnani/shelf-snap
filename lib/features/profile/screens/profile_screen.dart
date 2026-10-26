import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = AuthService().currentUser;

    // AuthGate handles login; build must not navigate
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final email = user.email ?? '';
    // Name is the part of the email before the @
    final name = email.contains('@') ? email.split('@').first : email;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final joined = user.metadata.creationTime;

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
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                initial,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (joined != null) ...[
            const SizedBox(height: 4),
            Text(
              'Member since ${_months[joined.month - 1]} ${joined.year}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.hint,
              ),
            ),
          ],
          const SizedBox(height: 24),

          librariesAsync.when(
            data: (libraries) {
              // Libraries store their own counts, so no extra reads
              final books = libraries.fold<int>(
                0,
                (sum, library) => sum + library.bookCount,
              );
              final shared = libraries
                  .where((library) => library.ownerId != user.uid)
                  .length;

              return Row(
                children: [
                  _StatTile(
                    icon: Icons.auto_stories_rounded,
                    value: libraries.length,
                    label: libraries.length == 1 ? 'Library' : 'Libraries',
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    icon: Icons.menu_book_rounded,
                    value: books,
                    label: books == 1 ? 'Book' : 'Books',
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    icon: Icons.people_alt_rounded,
                    value: shared,
                    label: 'Shared',
                  ),
                ],
              );
            },
            error: (err, stack) => Text(
              'Could not load stats: $err',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 32),

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

// One number with an icon and a label, sharing the row equally
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),
            Text('$value', style: theme.textTheme.titleLarge),
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

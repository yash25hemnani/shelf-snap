import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';

// A person in the friends lists: avatar, name and @username. The
// friendship doc only holds the username, so the profile loads for the
// name and avatar, with the username shown until it arrives.
class PersonTile extends ConsumerWidget {
  final String uid;
  final String username;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PersonTile({
    super.key,
    required this.uid,
    required this.username,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(otherUserProvider(uid)).valueOrNull;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      // The uid seeds the same clay avatar older accounts use
      leading: profile == null
          ? ClayAvatar(seed: uid)
          : UserAvatar(user: profile),
      title: Text(
        profile?.name ?? '@$username',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: profile == null
          ? null
          : Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: trailing,
    );
  }
}

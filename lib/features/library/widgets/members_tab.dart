import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

// List of a library's members, owner first, each with a role chip
class MembersTab extends ConsumerWidget {
  final LibraryModel library;

  const MembersTab({super.key, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(libraryMembersProvider(library.id!));
    final textTheme = Theme.of(context).textTheme;
    final viewerIsOwner = AuthService().currentUser?.uid == library.ownerId;

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const Center(child: Text('No members yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: members.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final member = members[index];
            final isOwner = member.uid == library.ownerId;
            final canRemove = viewerIsOwner && !isOwner;

            return ListTile(
              leading: UserAvatar(user: member),
              title: Text(member.name),
              subtitle: Text(
                '@${member.username}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOwner
                          ? AppColors.primarySoft
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOwner ? 'Owner' : 'Member',
                      style: textTheme.labelMedium?.copyWith(
                        color: isOwner
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (canRemove)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (_) => _confirmRemove(context, ref, member),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from library'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  // Asks the owner to confirm, then removes the member from the library
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    UserModel member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text("They'll lose access to this library's books."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // The row unmounts as soon as the local write lands, so grab this first
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .removeMember(library.id!, member.uid);
      messenger.showMessage('Removed ${member.name}');
    } catch (e) {
      messenger.showError("Couldn't remove member");
    }
  }
}

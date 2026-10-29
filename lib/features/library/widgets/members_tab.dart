import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

enum _MemberAction { toggleEdits, remove }

// List of a library's members, owner first, each with a role chip
class MembersTab extends ConsumerWidget {
  final LibraryModel library;

  const MembersTab({super.key, required this.library});

  // Asks the owner to confirm, then removes the member from the library
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    UserModel member,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      title: 'Remove ${member.name}?',
      message: "They'll lose access to this library's books.",
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

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

  // Lets a member edit the library's books, or takes it away. Easy to
  // undo, so there's no confirm.
  Future<void> _setEditor(
    BuildContext context,
    WidgetRef ref,
    UserModel member,
    bool isEditor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .setEditor(library.id!, member.uid, isEditor);
      messenger.showMessage(
        isEditor
            ? '${member.name} can now edit books'
            : '${member.name} can no longer edit books',
      );
    } catch (e) {
      debugPrint('setEditor failed: $e');
      messenger.showError("Couldn't update ${member.name}");
    }
  }

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
            // The owner is in editors too, but shows as Owner
            final canEdit = !isOwner && library.canEdit(member.uid);
            // Only the owner manages other members, never themselves
            final canManage = viewerIsOwner && !isOwner;

            final (label, color, softColor) = isOwner
                ? ('Owner', AppColors.primary, AppColors.primarySoft)
                : canEdit
                ? ('Can edit', AppColors.accent, AppColors.accentSoft)
                : ('Member', AppColors.textSecondary, AppColors.surfaceMuted);

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
                      color: softColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(color: color),
                    ),
                  ),
                  if (canManage)
                    PopupMenuButton<_MemberAction>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (action) => switch (action) {
                        _MemberAction.toggleEdits => _setEditor(
                          context,
                          ref,
                          member,
                          !canEdit,
                        ),
                        _MemberAction.remove => _confirmRemove(
                          context,
                          ref,
                          member,
                        ),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _MemberAction.toggleEdits,
                          child: ListTile(
                            leading: Icon(
                              canEdit
                                  ? Icons.edit_off_outlined
                                  : Icons.edit_outlined,
                            ),
                            title: Text(
                              canEdit ? 'Remove edits' : 'Allow edits',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MemberAction.remove,
                          child: ListTile(
                            leading: Icon(
                              Icons.person_remove_outlined,
                              color: AppColors.error,
                            ),
                            title: Text(
                              'Remove from library',
                              style: TextStyle(color: AppColors.error),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
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
}

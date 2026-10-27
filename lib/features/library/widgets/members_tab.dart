import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

// List of a library's members, owner first, each with a role chip
class MembersTab extends ConsumerWidget {
  final LibraryModel library;

  const MembersTab({super.key, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(libraryMembersProvider(library.id!));
    final textTheme = Theme.of(context).textTheme;

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

            return ListTile(
              leading: UserAvatar(user: member),
              title: Text(member.name),
              subtitle: Text(
                '@${member.username}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Container(
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
            );
          },
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

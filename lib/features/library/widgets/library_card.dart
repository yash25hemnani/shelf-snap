import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/widgets/member_avatars.dart';

// Library row: banner thumbnail, name, counts, member avatars and your role
class LibraryCard extends ConsumerWidget {
  final LibraryModel library;
  final VoidCallback? onTap;

  const LibraryCard({super.key, required this.library, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final members =
        ref.watch(libraryMembersProvider(library.id!)).valueOrNull ?? [];
    final isOwner = library.ownerId == AuthService().currentUser?.uid;

    final memberCount = library.members.length;
    final bookCount = library.bookCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primarySoft,
        highlightColor: AppColors.primarySoft.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(
                  image: library.bannerImage,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bookCount ${bookCount == 1 ? 'book' : 'books'}'
                      ' · $memberCount ${memberCount == 1 ? 'member' : 'members'}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MemberAvatars(members: members, size: 26),
                        const SizedBox(width: 8),
                        _RoleChip(isOwner: isOwner),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

// Small pill saying whether you own the library or are a member
class _RoleChip extends StatelessWidget {
  final bool isOwner;

  const _RoleChip({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOwner ? AppColors.primarySoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOwner ? "You're the owner" : "You're a member",
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isOwner ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

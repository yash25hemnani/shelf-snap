import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

// Overlapping member avatars, with a "+N" bubble when there are more than max
class MemberAvatars extends StatelessWidget {
  final List<UserModel> members;
  final int max;
  final double size;

  const MemberAvatars({
    super.key,
    required this.members,
    this.max = 4,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final shown = members.take(max).toList();
    final extra = members.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);

    if (count == 0) return const SizedBox.shrink();

    // Each avatar starts 70% of a width after the previous one, so they overlap
    final step = size * 0.7;

    return SizedBox(
      width: size + step * (count - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: _ring(UserAvatar(user: shown[i], radius: size / 2 - 2)),
            ),
          if (extra > 0)
            Positioned(
              left: step * shown.length,
              child: _ring(
                CircleAvatar(
                  radius: size / 2 - 2,
                  backgroundColor: AppColors.surfaceMuted,
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Background-coloured ring that separates overlapping avatars
  Widget _ring(Widget child) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

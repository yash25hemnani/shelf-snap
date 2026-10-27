import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

// Round avatar: the user's initial underneath, their photo on top once it loads
class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    // Sum of the uid's characters picks the colour, so it's the same everywhere
    final sum = user.uid.codeUnits.fold(0, (a, b) => a + b);
    final colors = AppColors.avatarColors[sum % AppColors.avatarColors.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors[1],
      foregroundImage: user.photoUrl != null
          ? NetworkImage(user.photoUrl!)
          : null,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
          color: colors[0],
        ),
      ),
    );
  }
}

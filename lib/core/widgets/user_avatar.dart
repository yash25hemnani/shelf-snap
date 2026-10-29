import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';

// Round avatar: the user's photo if they have one, otherwise their clay avatar
class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    // Older accounts have no saved seed, so the uid keeps their avatar stable
    final clay = ClayAvatar(seed: user.avatarSeed ?? user.uid, radius: radius);

    if (user.photoUrl == null) return clay;

    // Clay shows underneath until the photo loads
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceMuted,
      foregroundImage: NetworkImage(user.photoUrl!),
      child: clay,
    );
  }
}
